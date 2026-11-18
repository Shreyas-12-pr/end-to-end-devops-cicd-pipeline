package com.example.devops;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {
    @GetMapping("/api")
    public Map<String, String> home() {
        return Map.of(
            "application", "end-to-end-devops-app",
            "status", "running"
        );
    }
}
