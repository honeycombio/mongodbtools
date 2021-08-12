# mongodbtools

[![OSS Lifecycle](https://img.shields.io/osslifecycle/honeycombio/REPO)](https://github.com/honeycombio/home/blob/main/honeycomb-oss-lifecycle-and-practices.md)

Tools for sending MongoDB logs to [Honeycomb](https://honeycomb.io/).

## Summary

Two packages.  One for ingesting mongodb logs (logparser) and the other for query normalization (queryshape).

See [our docs](https://honeycomb.io/docs) for more about Honeycomb, and our [MongoDB-specific docs](https://honeycomb.io/docs/connect/mongodb/).

## Stats script

scripts/mongo_stats.sh is a shell script that collects some statistics from the server and the mongo instance and submits them to Honeycomb. It is a template for you use in creating your own stats scripts - it might work for you as is but likely needs modification to fit your environment. It has been tested against MongoDB 3.2.

Though it is technically a shell script, the majority of the logic in the script is javascript interpreted by the mongo client. The javascript functions parse server information and collect information about locks and other server statistics, then return it as a JSON object. That JSON object is the payload that is sent to Honeycomb.

It is intended to be run from cron every minute - internally it runs 4 times, submitting statistics every 15 seconds.

## Thanks

The logparser package is spiritually derived from Travis Cline's PEG
parser over at https://github.com/tmc/mongologtools.  While the parser
code itself is obviously different (this parser is hand-coded),
there are api similarities, and Travis's parser was definitely helpful
when figuring out just what the heck the logs were supposed to look like.

His license is replicated here:

```
Copyright (c) 2015, Travis Cline <travis.cline@gmail.com>

Permission to use, copy, modify, and/or distribute this software for any purpose
with or without fee is hereby granted, provided that the above copyright notice
and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
THIS SOFTWARE.
```

Another debt of gratitude goes out to Thomas Rückstieß and his
_awesome_ mongodb log spec at
https://github.com/rueckstiess/mongodb-log-spec.  In particular the
queryshape package attempts (and fails in some cases) to match up with his spec.

## Contributions

Features, bug fixes and other changes to mongodbtools are gladly accepted. Please
open issues or a pull request with your change. Remember to add your name to the
CONTRIBUTORS file!

All contributions will be released under the Apache License 2.0.
