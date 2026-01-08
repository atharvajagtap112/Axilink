package com.atharva.airpointerbe;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.web.bind.annotation.GetMapping;

@SpringBootTest
@ActiveProfiles("test")
class AirPointerBeApplicationTests {

    @GetMapping("/test")
    public String test() {
        return "test";
    }
}
