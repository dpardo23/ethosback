package com.ethoshub;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.testcontainers.junit.jupiter.Testcontainers;

// @Testcontainers(disabledWithoutDocker = true) is evaluated during JUnit 5 discovery
// — BEFORE Spring creates the ApplicationContext — so the context is never loaded
// when Docker is not reachable (rootless socket, CI without DinD, etc.).
@Testcontainers(disabledWithoutDocker = true)
@Import(TestcontainersConfiguration.class)
@SpringBootTest
class EthosHubApplicationTests {

    @Test
    void contextLoads() {
    }
}
