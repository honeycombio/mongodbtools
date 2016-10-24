#!/bin/bash

set -u
set -e
set -x

# this script expects two arguments: writekey and dataset.
# the third argument, if present, is the Honeycomb URL to which to send events

# this script will collect locks and a few other metrics from a locally running
# mongo instance and submit them to honeycomb as a single event. It should be
# called from cron every minute and will submit these metrics 4 times at 0, 15,
# 30, and 45 seconds.
#

# If you wish to kill queries, set FANGS="yes". When doing so, set these two
# variables to the age (in seconds) over which queries should be killed
FANGS="no"
SLOW_QUERY_KILL_AGE=30
NON_YIELDING_KILL_AGE=15

if [ $# -lt 2 ] ; then
  echo "two arguments required: writekey and dataset"
  exit 1
fi
writekey=$1
dataset=$2

if [ $# -eq 3 ] ; then
  url=$3
else
  url="https://api.honeycomb.io"
fi

getStats(){
  cat <<EOJS | mongo --quiet
function mongoCron(slowQueryKillAge, nonYieldingKillAge) {
  var data = {};

  function addLocks(dbname, locks) {
      function maybeAddLock(suffix, lockval) {
        if (typeof lockval != "undefined") {
          data[dbname+suffix] = lockval+0;
        }
      }

      maybeAddLock("_read_locks", locks.r);
      maybeAddLock("_Read_locks", locks.R);
      maybeAddLock("_write_locks", locks.w);
      maybeAddLock("_Write_locks", locks.W);
  }

  function addGlobalLocks() {
    var globalLocks = db.serverStatus().locks.Global.acquireCount;
    addLocks("global", globalLocks);
  }

  function addDatabaseLocks() {
    var dbnames = db.getMongo().getDBNames();
    for (var dbi in dbnames) {
      var adb = new Mongo().getDB(dbnames[dbi]);
      var dbLocks = adb.serverStatus().locks.Database.acquireCount;
      addLocks(dbnames[dbi], dbLocks);
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
      killOps(nonYieldOps);
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

  data.ismaster = db.isMaster().ismaster;
  data.version = db.serverStatus().version;
  addInProgMetrics();
  addGlobalLocks();
  addDatabaseLocks();

  print(JSON.stringify(data));
}
mongoCron($SLOW_QUERY_KILL_AGE,$NON_YIELDING_KILL_AGE)
EOJS
}

# run everything 4 times, sleeping 15s between
for i in {0..3} ; do
  payload=$(getStats)
  curl -q -X POST -H "X-Honeycomb-Team: $writekey" "${url}/1/events/${dataset}" -d "$payload"
  sleep 15
done
