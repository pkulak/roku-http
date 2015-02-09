Roku HTTP
=========

This is a small helper library to make HTTP requests and responses a bit more
enjoyable. It takes most of the pain out of concurrency as well as simple one-
offs. I made most of the functions return self, in an effort to make chaining
easy, however, it looks like Brightscript doesn't support a newline before _or_
after the "dot" operator, but it's still helpful for short lines.

There's no error handling or retry yet. I haven't quite figured out how that
should work.

Examples
--------

Single requests are pretty straight-forward:

    ip = NewRequest("http://api.ipify.org/").AddParam("format", "json").Execute()["ip"]
    print("Your IP is " + ip)

To run multiple requests in parallel, pass them all in a hash. The responses will
come back in the same format when the last response finishes:

    responses = ExecuteRequests({
        ip: NewRequest("http://api.ipify.org/").AddParam("format", "json"),
        reddit: {
            roku:    NewRequest("http://www.reddit.com/r/roku.json"),
            showyou: NewRequest("http://www.reddit.com/r/showyou.json")
        }
    })

    print("Your ip is " + responses.ip.ip)
    print("First Roku post: " + responses.reddit.roku.data.children[0].data.title)
    print("First Showyou post: " + responses.reddit.showyou.data.children[0].data.title)