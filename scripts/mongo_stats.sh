#!/bin/bash

set -u
set -e

# this script is a template - you will probably need to modify it to suit your
# environment. It has been tested to work against a Mongo 3.2 server running on
# Ubuntu linux.

# this script expects two arguments: a Honeycomb writekey and dataset name.
# the third argument, if present, is the mongo server to talk to
# the third argument, if present, is the Honeycomb URL to which to send events

# this script will collect locks and a few other metrics from a locally running
# mongo instance and submit them to honeycomb as a single event. It should be
# called from cron every minute and will submit these metrics 4 times at 0, 15,
# 30, and 45 seconds.
#

# TODO features to add
# calculate lock percentage instead of just counts/sec


# If you wish to kill queries, set FANGS="yes". When doing so, set these two
# variables to the age (in seconds) over which queries should be killed
FANGS="no"
SLOW_QUERY_KILL_AGE=30
NON_YIELDING_KILL_AGE=15

if [ $# -lt 2 ] ; then
  echo "Usage: $0 <writekey> <dataset> [host:port]"
  echo ""
  echo "$0 collects stats from a MongoDB instance and reports them to Honeycomb."
  echo "    It expects a Honeycomb writekey and dataset name."
  echo "    The optional third argument is a mongo target (default localhost:27017)."
  echo "    https://honeycomb.io"
  echo ""
  exit 1
fi
writekey=$1
dataset=$2
# replace spaces in the datase neame with %20s so curl works
dataset=${dataset// /%20}

# host:port for the mongo instance; defaults to localhost:27017
if [ $# -eq 3 ] ; then
  mongo_host=$3
else
  mongo_host="localhost:27017"
fi

# honeycomb url is the fourth argument, if present
if [ $# -eq 4 ] ; then
  url=$3
else
  url="https://api.honeycomb.io"
fi

getStats(){
  cuser=$1
  csystem=$2
  cidle=$3
  cwait=$4
  csteal=$5

  cat <<EOJS | mongo --quiet $mongo_host
function mongoCron(slowQueryKillAge, nonYieldingKillAge) {

  var data = {};

  function addLocks(obj, dbname, locks) {
      function maybeAddLock(suffix, lockval) {
        if (typeof lockval != "undefined") {
          obj[dbname+suffix] = lockval+0;
        }
      }

      maybeAddLock("_read_locks_per_sec", locks.r);
      maybeAddLock("_Read_locks_per_sec", locks.R);
      maybeAddLock("_write_locks_per_sec", locks.w);
      maybeAddLock("_Write_locks_per_sec", locks.W);
  }

  function addGlobalLocks(obj) {
    var globalLocks = db.serverStatus().locks.Global.acquireCount;
    addLocks(obj, "global", globalLocks);
  }

  function addDatabaseLocks(obj) {
    var dbnames = db.getMongo().getDBNames();
    for (var dbi in dbnames) {
      var adb = new Mongo().getDB(dbnames[dbi]);
      var dbLocks = adb.serverStatus().locks.Database.acquireCount;
      addLocks(obj, dbnames[dbi], dbLocks);
    }
  }

  function addInProgMetrics() {
    var inprog = db.currentOp().inprog;
    data.queue_size = inprog.length;

    var indexOps = inprog.filter(isIndexOp);
    var nonYieldingOps = inprog.filter(isNonYieldingOp);
    var slowQueries = inprog.filter(isSlowQuery);

    data.indexes_running = indexOps.length;
    data.nonyielding_running = nonYieldingOps.length;
    data.slow_queries_running = slowQueries.length;

    if ("$FANGS" == "yes") {
      killOps(nonYieldingOps);
      killOps(slowQueries);
    }
  }

  function isIndexOp(x) {
    return x.ns.indexOf('system.indexes') !== -1 && x.op == 'insert';
  }

  function isNonYieldingOp(x) {
    return db.isMaster().ismaster &&
      x.op === 'query' &&
      x.numYields < 1 &&
      x.secs_running > nonYieldingKillAge &&
      tojson(x.query).indexOf('nearSphere') &&
      !(x.msg && x.msg.indexOf('Index Build') !== -1);
  }

  function isSlowQuery(x) {
    return x.secs_running > slowQueryKillAge &&
      x.ns.indexOf('system') === -1 &&
      x.ns.indexOf('oplog') === -1 &&
      x.op !== 'getmore' &&
      !(x.query && x.query['\$comment'] && x.query['\$comment'].match(/push_id/)) &&
      !(x.msg && (x.msg.match(/bg index build/) || x.msg.indexOf('Index Build') !== -1 || x.msg.match(/compact extent/))) &&
      !(x.desc && x.desc.match(/repl writer worker/));
  }

  function killOps(ops) {
    ops.forEach(function(x) { db.killOp(x.opid); });
  }

  function getHoneycombDB() {
    var status = rs.status();
    var mongo;
    if (!status.ok) {
      mongo = db.getMongo();
    } else {
      mongo = new Mongo(status.set + "/" + status.members.map(function(m) { return m.name; }).join(","));
    }
    return mongo.getDB("honeycomb");
  }

  function calcLockChange() {
    var honeydb = getHoneycombDB();
    var myname = db.serverStatus().repl ? db.serverStatus().repl.me : db.getMongo().host;
    data.hostname = myname;

    var now = new Date();
    var newLocksData = {};

    addGlobalLocks(newLocksData);
    addDatabaseLocks(newLocksData);

    // fetch the old lock data
    var oldData = honeydb.locks.find({host:myname}).toArray();
    if (oldData.length > 0) {
      var oldLocksDoc = oldData[0];
      var oldLocksData = oldLocksDoc.locksData;

      // compute new_locks/sec for the values that are in both
      var timeDelta = (now - oldLocksDoc.time) / 1000;
      for (var k in newLocksData) {
        var oldVal = oldLocksData[k] || 0;
        var lockDiff = (newLocksData[k] - oldLocksData[k]) / timeDelta;
        // skip negative locks from server restart
        data[k] = lockDiff > 0 ? lockDiff : 0;
      }

      // remove old lock data
      honeydb.locks.remove({ _id: oldLocksDoc._id });
    }

    // store the current locks along with a timestamp
    honeydb.locks.insert({
      time: now,
      host: myname,
      locksData: newLocksData
    });
  }

  // Capture as much as possible from https://docs.mongodb.com/v3.2/reference/command/serverStatus/#repl
  func addReplSetAttrs() {
    var repl = db.serverStatus().repl;
    if (!repl) {
      return;
    }

    if (repl.setName) {
      data.replica_set_name = repl.setName;
    }
    if (repl.setVersion) {
      data.replica_set_version = repl.setVersion;
    }
    if (repl.primary) {
      data.replica_set_primary = repl.primary;
    }
    if (repl.electionId) {
      data.replica_set_election_id = repl.electionId.valueOf();
    }
  }

  db.getMongo().setSlaveOk();

  data.ismaster = db.isMaster().ismaster;
  data.version = db.serverStatus().version;

  addInProgMetrics()
  calcLockChange()
  addReplSetAttrs()

  data.cpu_user = $cuser
  data.cpu_system = $csystem
  data.cpu_idle = $cidle
  data.cpu_wait = $cwait
  data.cpu_steal = $csteal

  print(JSON.stringify(data));
}
mongoCron($SLOW_QUERY_KILL_AGE,$NON_YIELDING_KILL_AGE)
EOJS
}

# run everything 4 times. collect cpu util for 15s, then get mongo stats, repeat
for i in {0..3} ; do
  # grab 15sec worth of CPU utilization data
  cpu=($(vmstat 15 2 | tail -n 1 | awk '{print $13,$14,$15,$16,$17}'))
  cpu_user=${cpu[0]}
  cpu_system=${cpu[1]}
  cpu_idle=${cpu[2]}
  cpu_wait=${cpu[3]}
  cpu_steal=${cpu[4]}
  # grab the mongo data, hand it CPU util to stuff into the same event
  payload=$(getStats $cpu_user $cpu_system $cpu_idle $cpu_wait $cpu_steal | tail -n 1)
  # send the event to Honeycomb
  curl -q -X POST -H "X-Honeycomb-Team: $writekey" "${url}/1/events/${dataset}" -d "$payload"
done
