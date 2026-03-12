package com.example.hackathonbank.ai;

import com.example.hackathonbank.config.AiProperties;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class AiCapabilityService {

    private final AiProperties aiProperties;
    private final String apiKey;

    public AiCapabilityService(AiProperties aiProperties, @Value("${spring.ai.openai.api-key:}") String apiKey) {
        this.aiProperties = aiProperties;
        this.apiKey = apiKey;
    }

    public boolean isLiveAiEnabled() {
        return aiProperties.isEnabled() && StringUtils.hasText(apiKey) && !"demo-key".equals(apiKey);
    }
}
