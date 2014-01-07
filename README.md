# Purpose

The ultimate purpose of `ircshard` is to provide a basic mechanism for distributing IRC connections across multiple machines.

Right now, it only supports slave nodes (i.e. unsharded connection pools). In the future, however, it will be super easy to add a sharder which proxies different accounts to different slaves based on a SHA1 or similar hash.

Both the sharder and the slave will subclass the `Manager` class, making the abstraction apparent: the client has no idea what kind of `Manager` they are talking to. It could be a sharder, a slave, or anything I think of in the future.
