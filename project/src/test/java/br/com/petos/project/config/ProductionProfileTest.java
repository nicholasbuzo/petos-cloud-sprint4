package br.com.petos.project.config;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(properties = "spring.datasource.url=jdbc:h2:mem:petos-prod-test;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE")
@ActiveProfiles({"prod", "test"})
class ProductionProfileTest {

    @Autowired
    private ApplicationContext applicationContext;

    @Test
    @DisplayName("O perfil de producao nao deve criar contas de demonstracao nem expor o console H2")
    void productionDoesNotLoadDevelopmentResources() {
        assertThat(applicationContext.getBeansOfType(DevelopmentDataSeeder.class)).isEmpty();
        assertThat(applicationContext.containsBean("h2ConsoleSecurityFilterChain")).isFalse();
        assertThat(applicationContext.getEnvironment().getProperty("server.forward-headers-strategy"))
                .isEqualTo("native");
    }
}
