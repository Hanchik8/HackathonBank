package com.example.hackathonbank.service;

import com.example.hackathonbank.model.User;
import com.example.hackathonbank.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class UserContextService {

    private final UserRepository userRepository;

    public UserContextService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public User getCurrentUser() {
        return userRepository.findByFullName("Azizkhan")
                .orElseThrow(() -> new IllegalStateException("Пользователь Azizkhan не найден."));
    }
}
