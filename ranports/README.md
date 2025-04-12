# How to locate the java call stack trace corresponding to the tcp connection port

Recently we noticed that one of our java service maintained 18 localhost connections on the ephemeral ports.

```
c:\temp>netstat -anop tcp | find "7632"
  TCP    0.0.0.0:8090           0.0.0.0:0              LISTENING       7632
  TCP    127.0.0.1:59410        127.0.0.1:59411        ESTABLISHED     7632
  TCP    127.0.0.1:59411        127.0.0.1:59410        ESTABLISHED     7632
  TCP    127.0.0.1:59412        127.0.0.1:59413        ESTABLISHED     7632
  TCP    127.0.0.1:59413        127.0.0.1:59412        ESTABLISHED     7632
  TCP    127.0.0.1:59414        127.0.0.1:59415        ESTABLISHED     7632
  TCP    127.0.0.1:59415        127.0.0.1:59414        ESTABLISHED     7632
  TCP    127.0.0.1:59416        127.0.0.1:59417        ESTABLISHED     7632
  TCP    127.0.0.1:59417        127.0.0.1:59416        ESTABLISHED     7632
  TCP    127.0.0.1:59418        127.0.0.1:59419        ESTABLISHED     7632
  TCP    127.0.0.1:59419        127.0.0.1:59418        ESTABLISHED     7632
  TCP    127.0.0.1:59420        127.0.0.1:59421        ESTABLISHED     7632
  TCP    127.0.0.1:59421        127.0.0.1:59420        ESTABLISHED     7632
  TCP    127.0.0.1:59422        127.0.0.1:59423        ESTABLISHED     7632
  TCP    127.0.0.1:59423        127.0.0.1:59422        ESTABLISHED     7632
  TCP    127.0.0.1:59424        127.0.0.1:59425        ESTABLISHED     7632
  TCP    127.0.0.1:59425        127.0.0.1:59424        ESTABLISHED     7632
  TCP    127.0.0.1:59426        127.0.0.1:59427        ESTABLISHED     7632
  TCP    127.0.0.1:59427        127.0.0.1:59426        ESTABLISHED     7632
  ```

I was told we didn't establish these connections in our code.
Could it be done by JVM itself? but we don't enable JMX, RMI etc. Third party libraries? We did use quite a few libraries, but who is the culprit? how to locate it?

It was a challenge, as there is not utility when can directly tells the relationship between tcp port and java thread, especially on Windows platform. As least I could not find one.

In Process Monitor I added 2 filters
Process Name is `prunsrv.exe`
Operation is `TCP Accept`

then I started the service and it captured,

I got

```
"Frame","Module","Location","Address","Path"
"0","ntoskrnl.exe","WmiTraceMessageVa + 0x2edb","0xfffff80065f0ce7b","C:\Windows\system32\ntoskrnl.exe"
"1","tcpip.sys","tcpip.sys + 0x78f59","0xfffff807a97f8f59","C:\Windows\System32\drivers\tcpip.sys"
"2","tcpip.sys","tcpip.sys + 0x3d146","0xfffff807a97bd146","C:\Windows\System32\drivers\tcpip.sys"
"3","tcpip.sys","tcpip.sys + 0x3b04c","0xfffff807a97bb04c","C:\Windows\System32\drivers\tcpip.sys"
"4","tcpip.sys","tcpip.sys + 0x2f8cd","0xfffff807a97af8cd","C:\Windows\System32\drivers\tcpip.sys"
"5","tcpip.sys","tcpip.sys + 0x2e895","0xfffff807a97ae895","C:\Windows\System32\drivers\tcpip.sys"
"6","tcpip.sys","tcpip.sys + 0x2d944","0xfffff807a97ad944","C:\Windows\System32\drivers\tcpip.sys"
"7","tcpip.sys","tcpip.sys + 0x8acbd","0xfffff807a980acbd","C:\Windows\System32\drivers\tcpip.sys"
"8","tcpip.sys","tcpip.sys + 0x7c1fb","0xfffff807a97fc1fb","C:\Windows\System32\drivers\tcpip.sys"
"9","tcpip.sys","tcpip.sys + 0x7bfd3","0xfffff807a97fbfd3","C:\Windows\System32\drivers\tcpip.sys"
"10","ntoskrnl.exe","KeSynchronizeExecution + 0x264e","0xfffff80065dbb88e","C:\Windows\system32\ntoskrnl.exe"
"11","ntoskrnl.exe","KeSynchronizeExecution + 0x260c","0xfffff80065dbb84c","C:\Windows\system32\ntoskrnl.exe"
"12","ntoskrnl.exe","Ordinal7 + 0x476","0xfffff80065cbd896","C:\Windows\system32\ntoskrnl.exe"
"13","ntoskrnl.exe","Ordinal7 + 0x1bc","0xfffff80065cbd5dc","C:\Windows\system32\ntoskrnl.exe"
"14","ntoskrnl.exe","Ordinal7 + 0x33","0xfffff80065cbd453","C:\Windows\system32\ntoskrnl.exe"
"15","ntoskrnl.exe","KeExpandKernelStackAndCalloutEx + 0x1d","0xfffff80065cbd40d","C:\Windows\system32\ntoskrnl.exe"
"16","tcpip.sys","tcpip.sys + 0x7ce35","0xfffff807a97fce35","C:\Windows\System32\drivers\tcpip.sys"
"17","tcpip.sys","tcpip.sys + 0xb8af4","0xfffff807a9838af4","C:\Windows\System32\drivers\tcpip.sys"
"18","tcpip.sys","tcpip.sys + 0x5160c","0xfffff807a97d160c","C:\Windows\System32\drivers\tcpip.sys"
"19","tcpip.sys","tcpip.sys + 0x2b221","0xfffff807a97ab221","C:\Windows\System32\drivers\tcpip.sys"
"20","tcpip.sys","tcpip.sys + 0x6f39f","0xfffff807a97ef39f","C:\Windows\System32\drivers\tcpip.sys"
"21","tcpip.sys","tcpip.sys + 0x10575","0xfffff807a9790575","C:\Windows\System32\drivers\tcpip.sys"
"22","tcpip.sys","tcpip.sys + 0x104c8","0xfffff807a97904c8","C:\Windows\System32\drivers\tcpip.sys"
"23","tcpip.sys","tcpip.sys + 0xf378","0xfffff807a978f378","C:\Windows\System32\drivers\tcpip.sys"
"24","tcpip.sys","tcpip.sys + 0xf128","0xfffff807a978f128","C:\Windows\System32\drivers\tcpip.sys"
"25","tcpip.sys","tcpip.sys + 0xe82d","0xfffff807a978e82d","C:\Windows\System32\drivers\tcpip.sys"
"26","tcpip.sys","tcpip.sys + 0xdb6c","0xfffff807a978db6c","C:\Windows\System32\drivers\tcpip.sys"
"27","afd.sys","afd.sys + 0x57402","0xfffff80068b87402","C:\Windows\system32\drivers\afd.sys"
"28","afd.sys","afd.sys + 0x59b1d","0xfffff80068b89b1d","C:\Windows\system32\drivers\afd.sys"
"29","ntoskrnl.exe","IofCallDriver + 0x59","0xfffff80065c56c69","C:\Windows\system32\ntoskrnl.exe"
"30","ntoskrnl.exe","NtDeviceIoControlFile + 0x221","0xfffff800661e11d1","C:\Windows\system32\ntoskrnl.exe"
"31","ntoskrnl.exe","NtClose + 0xffc","0xfffff800661e0f3c","C:\Windows\system32\ntoskrnl.exe"
"32","ntoskrnl.exe","NtDeviceIoControlFile + 0x56","0xfffff800661e1006","C:\Windows\system32\ntoskrnl.exe"
"33","ntoskrnl.exe","setjmpex + 0x78b5","0xfffff80065dc9305","C:\Windows\system32\ntoskrnl.exe"
"34","ntdll.dll","NtDeviceIoControlFile + 0x14","0x7ffad85ffad4","C:\Windows\System32\ntdll.dll"
"35","mswsock.dll","WSPStartup + 0x81ed","0x7ffad3d4cc8d","C:\Windows\System32\mswsock.dll"
"36","mswsock.dll","WSPStartup + 0x7ed0","0x7ffad3d4c970","C:\Windows\System32\mswsock.dll"
"37","mswsock.dll","WSPStartup + 0x8010","0x7ffad3d4cab0","C:\Windows\System32\mswsock.dll"
"38","ws2_32.dll","connect + 0x9b","0x7ffad6d2169b","C:\Windows\System32\ws2_32.dll"
"39","nio.dll","Java_sun_nio_ch_Net_connect0 + 0x78","0x7ffabeee3018","C:\Program Files\Our service\jre\bin\nio.dll"
"40","<unknown>","0x13e8b07","0x13e8b07",""
```
that stack trace shows that a Java NIO socket connection is being made, specifically via:

Java_sun_nio_ch_Net_connect0 in nio.dll, which is the native method for SocketChannel.connect() in Java NIO.

A great progress, now let us see who called `SocketChannel.connect()`. Byte Buddy came to rescue. I created an java agent. Please see the code in AgentPremain.java.

After applying the agent to our service, I saw the logs.

```
nanoart enter  premain
[Agent] sun.nio.ch.SocketChannelImpl.connect() called
[Agent] Destination: 127.0.0.1:59410
	at java.lang.Thread.getStackTrace(Thread.java:1564)
	at sun.nio.ch.SocketChannelImpl.connect(SocketChannelImpl.java:616)
	at java.nio.channels.SocketChannel.open(SocketChannel.java:189)
	at sun.nio.ch.PipeImpl$Initializer$LoopbackConnector.run(PipeImpl.java:127)
	at sun.nio.ch.PipeImpl$Initializer.run(PipeImpl.java:76)
	at sun.nio.ch.PipeImpl$Initializer.run(PipeImpl.java:61)
	at java.security.AccessController.doPrivileged(Native Method)
	at sun.nio.ch.PipeImpl.<init>(PipeImpl.java:171)
	at sun.nio.ch.SelectorProviderImpl.openPipe(SelectorProviderImpl.java:50)
	at java.nio.channels.Pipe.open(Pipe.java:155)
	at sun.nio.ch.WindowsSelectorImpl.<init>(WindowsSelectorImpl.java:142)
	at sun.nio.ch.WindowsSelectorProvider.openSelector(WindowsSelectorProvider.java:44)
	at io.netty.channel.nio.NioEventLoop.openSelector(NioEventLoop.java:173)
	at io.netty.channel.nio.NioEventLoop.<init>(NioEventLoop.java:142)
	at io.netty.channel.nio.NioEventLoopGroup.newChild(NioEventLoopGroup.java:146)
	at io.netty.channel.nio.NioEventLoopGroup.newChild(NioEventLoopGroup.java:37)
	at io.netty.util.concurrent.MultithreadEventExecutorGroup.<init>(MultithreadEventExecutorGroup.java:84)
	at io.netty.util.concurrent.MultithreadEventExecutorGroup.<init>(MultithreadEventExecutorGroup.java:58)
	at io.netty.util.concurrent.MultithreadEventExecutorGroup.<init>(MultithreadEventExecutorGroup.java:47)
	at io.netty.channel.MultithreadEventLoopGroup.<init>(MultithreadEventLoopGroup.java:59)
	at io.netty.channel.nio.NioEventLoopGroup.<init>(NioEventLoopGroup.java:86)
	at io.netty.channel.nio.NioEventLoopGroup.<init>(NioEventLoopGroup.java:81)
	at io.netty.channel.nio.NioEventLoopGroup.<init>(NioEventLoopGroup.java:68)
	at org.asynchttpclient.netty.channel.NioTransportFactory.newEventLoopGroup(NioTransportFactory.java:32)
	at org.asynchttpclient.netty.channel.NioTransportFactory.newEventLoopGroup(NioTransportFactory.java:21)
	at org.asynchttpclient.netty.channel.ChannelManager.<init>(ChannelManager.java:133)
	at org.asynchttpclient.DefaultAsyncHttpClient.<init>(DefaultAsyncHttpClient.java:92)
	at org.asynchttpclient.Dsl.asyncHttpClient(Dsl.java:32)
	at com.xxxx.yyyy.AsyncRestClient.<init>(AsyncRestClient.java:98)
```

We used [async-http-client](https://github.com/AsyncHttpClient/async-http-client) which established these connections!
Now it is down to my team members to fix/improve this part.

During the investigation, I noticed if I restart the service quickly, the ephemeral ports won't be recycled, it will use a new set  above the older one.

On Windows there are 16K ephemeral ports
```
>netsh int ipv4 show dynamicport tcp

Protocol tcp Dynamic Port Range
---------------------------------
Start Port      : 49152
Number of Ports : 16384
```

Now you can imagine an extreme case, The system will run out of the ephemeral ports and become dead if the service by accident enters a loop of stop/start. 
