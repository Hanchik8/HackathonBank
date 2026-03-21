package com.example.hackathonbank;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class HackathonBankApplication {

    public static void main(String[] args) {
        SpringApplication.run(HackathonBankApplication.class, args);
    }

}
