package com.ethoshub.controller;

import java.util.HashMap;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class HealthController {

    private final JdbcTemplate jdbcTemplate;

    // Inyectamos JdbcTemplate para ejecutar SQL nativo directo a Supabase
    public HealthController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping("/ping")
    public ResponseEntity<Map<String, Object>> ping() {
        Map<String, Object> response = new HashMap<>();
        response.put("api", "online");

        try {
            // Intentamos ejecutar una consulta simple a la base de datos
            jdbcTemplate.queryForObject("SELECT 1", Integer.class);
            response.put("database", "connected");
            response.put("message", "Flujo completo exitoso: API y Supabase están respondiendo.");
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            response.put("database", "disconnected");
            response.put("error", e.getMessage());
            // Retorna un código 503 (Servicio No Disponible) si la DB falla
            return ResponseEntity.status(503).body(response);
        }
    }
}