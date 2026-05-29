package com.ethoshub.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**") // Aplica a todos los endpoints
                .allowedOrigins(
                    "http://localhost:3000", // Para React/Next.js local
                    "http://localhost:5173", // Por si usas Vite local
                    "https://tu-dominio-en-vercel.vercel.app" // Tu futuro frontend en producción
                )
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true);
    }
}