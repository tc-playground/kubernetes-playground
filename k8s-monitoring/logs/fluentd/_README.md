# Fluentd

## Introduction

1. `Fluentd` decouples `data sources` from `backend systems` by providing a `unified logging layer`.

2. `Fluentd` is a `data collector` for building the `unified logging layer`.

3. `Fluentd` is installed on a `server`.

4. `Fluentd` runs as background process to `collect`, `parse`, `transform`, `analyze` and `store` various types of **data**.

5. `Fluentd` internally prefers to use the `JSON` data format as this has a `flexible schema`.

6. `Fluentd` has a `pluggable` architecture to extend functionality. It has lots of existing `datasources` and `dataoutputs`.

7. `Fluentd` uses `minimal resources` (C/Ruby 30MB implementation).

8. `Fluentd` supports `memory` and `file` based `buffering` to prevent inter-node data loss.

9. `Fluentd` also supports robust failover and can be set up for high availability.

> Fluentd is a `json` format, `push` based, `logshipper`.

---

## Details

1. __Plugins__ - `Fluentd` has 3 types of `plugin`: 

    1. __Input__

    2. __Buffering__
    
    3. __Output__

2. __Events__ - `Fluent` acts on `events`, these have 3 attributes:

    1. __Timestamp__ - The timestamp of the event.

    2. __Tag__ - Used for routing so Fluentd knows what to do with it.

    3. __Record__ - The log data - usually normalised to a JSON format.

3. __Input Plugin Examples__

    1. `in_tail` - Tails a local file log and parses each line, converts it into events and sends it to the buffer.

4. __Buffer Plugin Examples__

    1. `automatic retry`, `exponential retry`

5. __Output Plugin Examples__

    1. `XXX-db` - Push results to db XXX.

    2. `copy` - Copy the result and push it to several dataoutputs.


---

## References

* [Home](https://www.fluentd.org)

    * [Data Inputs](https://www.fluentd.org/datasources)

    * [Data outputs](https://www.fluentd.org/dataoutputs)

* [Overview - YouTube](https://www.fluentd.org/videos)

* [Example](https://www.fluentd.org/guides/recipes/rsyslogd-aggregation)

* [Unified Logging Layer](https://www.fluentd.org/blog/unified-logging-layer)
