package cl.duoc.cloudnative.documents;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.*;

class PdfGeneratorTest {

    @Test
    void generatesPdf() throws Exception {

        CreateDocumentRequest request = new CreateDocumentRequest(
                "USR001",
                "Lian Lopez",
                "EVT001",
                "RockFest 2026",
                LocalDate.of(2026, 12, 15),
                new BigDecimal("30000")
        );

        byte[] bytes = new PdfGenerator().generate(request);

        assertTrue(bytes.length > 200);
        assertEquals(
                "%PDF-",
                new String(
                        bytes,
                        0,
                        5,
                        java.nio.charset.StandardCharsets.US_ASCII
                )
        );
    }
}
