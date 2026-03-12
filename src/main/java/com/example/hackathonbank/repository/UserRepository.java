package com.example.hackathonbank.repository;

import com.example.hackathonbank.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByFullName(String fullName);
}
