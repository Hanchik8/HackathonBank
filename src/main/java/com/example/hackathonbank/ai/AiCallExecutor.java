package com.example.hackathonbank.ai;

import com.example.hackathonbank.config.AiProperties;
import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicInteger;

@Component
public class AiCallExecutor {

    private final ExecutorService executorService;
    private final Duration timeout;

    public AiCallExecutor(AiProperties aiProperties) {
        this.timeout = Duration.ofSeconds(Math.max(1, aiProperties.getRequestTimeoutSeconds()));
        AtomicInteger threadCounter = new AtomicInteger(1);
        ThreadFactory threadFactory = runnable -> {
            Thread thread = new Thread(runnable);
            thread.setName("ai-call-" + threadCounter.getAndIncrement());
            thread.setDaemon(true);
            return thread;
        };
        this.executorService = Executors.newCachedThreadPool(threadFactory);
    }

    public <T> T execute(Callable<T> task) throws Exception {
        Future<T> future = executorService.submit(task);
        try {
            return future.get(timeout.toMillis(), TimeUnit.MILLISECONDS);
        } catch (TimeoutException exception) {
            future.cancel(true);
            throw new IllegalStateException(
                    "AI call timed out after %d seconds.".formatted(timeout.toSeconds()),
                    exception
            );
        } catch (InterruptedException exception) {
            future.cancel(true);
            Thread.currentThread().interrupt();
            throw new IllegalStateException("AI call was interrupted.", exception);
        } catch (ExecutionException exception) {
            Throwable cause = exception.getCause();
            if (cause instanceof Exception nestedException) {
                throw nestedException;
            }
            throw new IllegalStateException("AI call failed.", cause);
        }
    }

    @PreDestroy
    void shutdown() {
        executorService.shutdownNow();
    }
}
