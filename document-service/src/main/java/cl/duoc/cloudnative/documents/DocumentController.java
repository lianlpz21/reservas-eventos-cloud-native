package cl.duoc.cloudnative.documents;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClient;

import java.io.IOException;
import java.time.LocalDate;
import java.util.Map;

@RestController
@RequestMapping("/api/tickets")
public class DocumentController {

    private final PdfGenerator generator;
    private final RestClient storage;

    public DocumentController(
            PdfGenerator generator,
            @Value("${storage.service.url:http://localhost:8081}") String url) {

        this.generator = generator;
        this.storage = RestClient.builder()
                .baseUrl(url)
                .build();
    }

    // CREAR TICKET
    @PostMapping
    public ResponseEntity<Map> create(
            @Valid @RequestBody CreateDocumentRequest input) throws IOException {

        byte[] pdf = generator.generate(input);

        ByteArrayResource resource = new ByteArrayResource(pdf) {
            @Override
            public String getFilename() {
                return "ticket.pdf";
            }
        };

        MultiValueMap<String, Object> form = new LinkedMultiValueMap<>();

        form.add("file", resource);
        form.add("clientId", input.userId());
        form.add("date", input.eventDate().toString());

        Map result = storage.post()
                .uri("/internal/storage")
                .contentType(MediaType.MULTIPART_FORM_DATA)
                .body(form)
                .retrieve()
                .body(Map.class);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(result);
    }

    // ACTUALIZAR TICKET
    @PutMapping("/{userId}/{date}/{filename:.+}")
    public ResponseEntity<Map> update(
            @PathVariable String userId,
            @PathVariable String date,
            @PathVariable String filename,
            @Valid @RequestBody CreateDocumentRequest input) throws IOException {

        byte[] pdf = generator.generate(input);

        ByteArrayResource resource = new ByteArrayResource(pdf) {
            @Override
            public String getFilename() {
                return filename;
            }
        };

        MultiValueMap<String, Object> form = new LinkedMultiValueMap<>();
        form.add("file", resource);

        Map result = storage.put()
                .uri(builder -> builder
                        .path("/internal/storage/{clientId}/{date}/{filename}")
                        .build(userId, date, filename))
                .contentType(MediaType.MULTIPART_FORM_DATA)
                .body(form)
                .retrieve()
                .body(Map.class);

        return ResponseEntity.ok(result);
    }

    // CONSULTAR HISTORIAL
    @GetMapping("/history/{userId}")
    public ResponseEntity<Map> history(
            @PathVariable String userId,
            @RequestParam(required = false) LocalDate date) {

        Map result;

        if (date != null) {
            result = storage.get()
                    .uri(builder -> builder
                            .path("/internal/storage/history/{clientId}")
                            .queryParam("date", date)
                            .build(userId))
                    .retrieve()
                    .body(Map.class);
        } else {
            result = storage.get()
                    .uri(builder -> builder
                            .path("/internal/storage/history/{clientId}")
                            .build(userId))
                    .retrieve()
                    .body(Map.class);
        }

        return ResponseEntity.ok(result);
    }

    // DESCARGAR TICKET
    @GetMapping("/{userId}/{date}/{filename:.+}")
    public ResponseEntity<byte[]> download(
            @PathVariable String userId,
            @PathVariable String date,
            @PathVariable String filename) {

        byte[] file = storage.get()
                .uri(builder -> builder
                        .path("/internal/storage/{clientId}/{date}/{filename}")
                        .build(userId, date, filename))
                .retrieve()
                .body(byte[].class);

        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(
                        HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\"" + filename + "\""
                )
                .body(file);
    }
}