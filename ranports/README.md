# Identifying the Java Call Stack Behind a TCP Connection Port
Recently, we observed that one of our Java services was maintaining 18 localhost connections using ephemeral ports.

```
c:\temp>netstat -anop tcp | find "7632"
  TCP    0.0.0.0:8090           0.0.0.0:0              LISTENING       7632
  TCP    127.0.0.1:59410        127.0.0.1:59411        ESTABLISHED     7632
  ...
  TCP    127.0.0.1:59427        127.0.0.1:59426        ESTABLISHED     7632
```  
The process ID `7632` belongs to our Java service, but according to the team, these connections weren't explicitly created in our code. Could the JVM be responsible? We don’t use JMX or RMI, but we do rely on several third-party libraries. So the question became—who is creating these connections?

Unfortunately, there's no out-of-the-box tool (especially on Windows) that maps TCP connections directly to Java threads or call stacks. So I had to dig deeper.

## Using Process Monitor
I turned to [Process Monitor](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon) and set up the following filters:

- Process Name: `prunsrv.exe`
- Operation: `TCP Accept`

Upon restarting the service, we captured a trace, and here’s a snippet of the call stack:

```
...
39","nio.dll","Java_sun_nio_ch_Net_connect0 + 0x78","C:\Program Files\Our service\jre\bin\nio.dll"
40","<unknown>","0x13e8b07","0x13e8b07",""
```

This indicated that a native method `Java_sun_nio_ch_Net_connect0` was being invoked—this is part of Java NIO’s `SocketChannel.connect()`.

## Tracing the Java Caller with Byte Buddy
The next step was to identify who in our Java code was calling this method. I wrote a [custom Java agent](./AgentPremain.java) using [Byte Buddy](https://bytebuddy.net/) to intercept `SocketChannel.connect()` calls and print stack traces.

After attaching the agent to our service, we saw logs like this:

```
[Agent] sun.nio.ch.SocketChannelImpl.connect() called
[Agent] Destination: 127.0.0.1:59410
	at java.lang.Thread.getStackTrace(Thread.java:1564)
	at sun.nio.ch.SocketChannelImpl.connect(SocketChannelImpl.java:616)
	...
	at org.asynchttpclient.Dsl.asyncHttpClient(Dsl.java:32)
	at com.our.service.AsyncRestClient.<init>(AsyncRestClient.java:98)
```

That stack trace revealed the culprit: the [Async Http Client](https://github.com/AsyncHttpClient/async-http-client) library. It was internally creating Pipe connections using loopback sockets via Java NIO.

The mystery was solved! Now it’s up to our team to revisit and optimize that part of the code.

## Bonus Observation: Ephemeral Port Exhaustion
During the investigation, I noticed that restarting the service quickly led to new ephemeral ports being used, rather than reusing old ones.

On Windows, there are 16,384 ephemeral TCP ports available by default:

```
> netsh int ipv4 show dynamicport tcp

Protocol tcp Dynamic Port Range
---------------------------------
Start Port      : 49152
Number of Ports : 16384
```

In an extreme case—say, the service enters a rapid restart loop—this could quickly exhaust the ephemeral port range, potentially rendering the system unresponsive.

