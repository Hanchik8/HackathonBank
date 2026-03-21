package com.example.hackathonbank.service;

import com.example.hackathonbank.model.User;
import com.example.hackathonbank.model.UserSettings;
import com.example.hackathonbank.repository.UserSettingsRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserSettingsServiceTests {

    @Mock
    private UserSettingsRepository userSettingsRepository;

    @Mock
    private UserContextService userContextService;

    private UserSettingsService userSettingsService;

    @BeforeEach
    void setUp() {
        userSettingsService = new UserSettingsService(userSettingsRepository, userContextService);
    }

    @Test
    void getSettingsRecoversWhenConcurrentInsertWinsRace() {
        User user = new User("Azizkhan");
        ReflectionTestUtils.setField(user, "id", 1L);
        UserSettings persisted = new UserSettings(user, true, false, LocalDate.now());

        when(userContextService.getCurrentUser()).thenReturn(user);
        when(userSettingsRepository.findByUserId(1L))
                .thenReturn(Optional.empty())
                .thenReturn(Optional.of(persisted));
        when(userSettingsRepository.saveAndFlush(any(UserSettings.class)))
                .thenThrow(new DataIntegrityViolationException("duplicate"));

        UserSettings result = userSettingsService.getSettings();

        assertThat(result).isSameAs(persisted);
        verify(userSettingsRepository, times(2)).findByUserId(1L);
    }
}
