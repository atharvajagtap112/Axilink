package com.atharva.airpointerbe.config;





import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.*;
import org.springframework.web.socket.server.standard.ServletServerContainerFactoryBean;


@Configuration
    @EnableWebSocketMessageBroker
    public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

        @Override
        public void registerStompEndpoints(StompEndpointRegistry registry) {
            // Pure WebSocket without SockJS
            registry.addEndpoint("/ws").setAllowedOrigins("*");
        }

        @Override
        public void configureMessageBroker(MessageBrokerRegistry registry) {
            // Prefix for messages from client to controller
            registry.setApplicationDestinationPrefixes("/app");

            // Prefix for messages from controller to client (subscribed)
            registry.enableSimpleBroker("/topic");
        }

    @Bean
    public ServletServerContainerFactoryBean createWebSocketContainer() {
        ServletServerContainerFactoryBean container = new ServletServerContainerFactoryBean();
        // Increase WebSocket message sizes (1MB)
        container.setMaxTextMessageBufferSize(10024 * 10024);
        container.setMaxBinaryMessageBufferSize(10024 * 10024);
        return container;
    }

    /**
     * Configure the STOMP protocol handler to allow larger messages
     */
    @Override
    public void configureWebSocketTransport(WebSocketTransportRegistration registry) {
        // Increase STOMP buffer size to 1MB (from default 64KB)
        registry.setMessageSizeLimit(10024 * 10024); // Message size limit in bytes
        registry.setSendTimeLimit(20 * 1000);      // Time limit for sending in milliseconds
        registry.setSendBufferSizeLimit(10024 * 10024); // Buffer size limit in bytes
    }
    }


