package com.atharva.airpointerbe.config;





import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;
import org.springframework.web.socket.config.annotation.*;
import org.springframework.web.socket.server.standard.ServletServerContainerFactoryBean;


@Configuration
    @EnableWebSocketMessageBroker
    public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

        @Override
        public void registerStompEndpoints(StompEndpointRegistry registry) {

            registry.addEndpoint("/ws").setAllowedOrigins("*");
        }

        @Override
        public void configureMessageBroker(MessageBrokerRegistry registry) {

            registry.setApplicationDestinationPrefixes("/app");


            registry.enableSimpleBroker("/topic").
                    setHeartbeatValue(new long[]{10000, 10000}).
                    setTaskScheduler(taskScheduler());
        }

        /**
         * Inbound channel carries every message coming FROM clients (motion, touch,
         * screen frames). At the Spring default it is single-threaded, which becomes
         * the throughput ceiling once many devices publish concurrently. Size it to
         * the host so frames from different devices are processed in parallel.
         */
        @Override
        public void configureClientInboundChannel(ChannelRegistration registration) {
            registration.taskExecutor()
                    .corePoolSize(8)
                    .maxPoolSize(32)
                    .queueCapacity(1000);
        }

        /**
         * Outbound channel carries every message going TO subscribers (the relayed
         * screen frames are the heavy ones). Parallelize fan-out across devices.
         */
        @Override
        public void configureClientOutboundChannel(ChannelRegistration registration) {
            registration.taskExecutor()
                    .corePoolSize(8)
                    .maxPoolSize(32)
                    .queueCapacity(1000);
        }

    @Bean
    public ServletServerContainerFactoryBean createWebSocketContainer() {
        ServletServerContainerFactoryBean container = new ServletServerContainerFactoryBean();




        // Mirror frames are chunked to ~900 KB on the client, so the per-frame load is
        // tiny. The cap exists for the occasional un-chunked lossless-PNG OCR screenshot,
        // which can run several MB on a high-res display. 8 MB covers that worst case
        // while staying far below the old 20 MB and keeping per-device memory bounded.
        container.setMaxTextMessageBufferSize(8 * 1024 * 1024);
        container.setMaxBinaryMessageBufferSize(8 * 1024 * 1024);
        return container;
    }

    /**
     * Configure the STOMP protocol handler to allow larger messages
     */
    @Override
    public void configureWebSocketTransport(WebSocketTransportRegistration registry) {






        registry
                .setMessageSizeLimit(8 * 1024 * 1024)
                .setSendBufferSizeLimit(8 * 1024 * 1024)
                // Shorter send window: a slow/stalled subscriber is disconnected
                // instead of letting its outbound buffer back up and consume memory.
                .setSendTimeLimit(20 * 1000);
    }

    @Bean
    public TaskScheduler taskScheduler() {
        ThreadPoolTaskScheduler scheduler = new ThreadPoolTaskScheduler();
        scheduler.setPoolSize(2);
        scheduler.setThreadNamePrefix("ws-heartbeat-");
        scheduler.initialize();
        return scheduler;
    }
    }


