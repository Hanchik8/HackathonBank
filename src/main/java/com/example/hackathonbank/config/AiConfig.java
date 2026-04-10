package com.example.hackathonbank.config;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.Map;

@Configuration
@EnableConfigurationProperties({AiProperties.class, CorsProperties.class})
public class AiConfig {

    @Bean
    public ChatClient aiChatClient(ChatClient.Builder builder,
                                   AiProperties aiProperties,
                                   @Value("${spring.ai.openai.base-url:https://api.x.ai/v1}") String baseUrl) {
        OpenAiChatOptions.Builder optionsBuilder = OpenAiChatOptions.builder()
                .model(aiProperties.getPrimaryModel())
                .temperature(aiProperties.getTemperature());

        if (isOpenRouter(baseUrl) && !aiProperties.getFallbackModels().isEmpty()) {
            optionsBuilder.extraBody(Map.of("models", aiProperties.getFallbackModels()));
        }

        return builder.defaultOptions(optionsBuilder.build()).build();
    }

    private boolean isOpenRouter(String baseUrl) {
        return baseUrl != null && baseUrl.contains("openrouter.ai");
    }
}
