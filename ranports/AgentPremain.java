package com.omnine.agent;

import net.bytebuddy.agent.builder.AgentBuilder;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.matcher.ElementMatchers;
import net.bytebuddy.description.type.TypeDescription;
import net.bytebuddy.dynamic.DynamicType;
import net.bytebuddy.utility.JavaModule;

import java.lang.instrument.Instrumentation;


public class AgentPremain {
    public static void premain(String agentArgs, Instrumentation inst) {
        System.out.println("nanoart enter  premain");

        new AgentBuilder.Default()
                .ignore(ElementMatchers.nameStartsWith("net.bytebuddy."))
                .type(ElementMatchers.named("sun.nio.ch.SocketChannelImpl"))
                .transform(new AgentBuilder.Transformer() {
                    @Override
                    public DynamicType.Builder<?> transform(
                            DynamicType.Builder<?> builder,
                            TypeDescription typeDescription,
                            ClassLoader classLoader,
                            JavaModule module,
                            java.security.ProtectionDomain protectionDomain) {

                        return builder.visit(Advice.to(ConnectAdvice.class)
                                .on(ElementMatchers.named("connect")));
                    }
                })
                .installOn(inst);
    }

    public static class ConnectAdvice {
        @Advice.OnMethodEnter
        public static void onEnter(@Advice.Argument(0) java.net.SocketAddress socketAddress) {
            System.out.println("[Agent] sun.nio.ch.SocketChannelImpl.connect() called");
    
            if (socketAddress instanceof java.net.InetSocketAddress) {
                java.net.InetSocketAddress inetSocketAddress = (java.net.InetSocketAddress) socketAddress;
                int destinationPort = inetSocketAddress.getPort();
                String destinationHost = inetSocketAddress.getHostString();
    
                System.out.println("[Agent] Destination: " + destinationHost + ":" + destinationPort);
            } else {
                System.out.println("[Agent] Unable to determine destination port (not an InetSocketAddress)");
            }
    
            for (StackTraceElement e : Thread.currentThread().getStackTrace()) {
                System.out.println("\tat " + e);
            }
        }
    }


}

