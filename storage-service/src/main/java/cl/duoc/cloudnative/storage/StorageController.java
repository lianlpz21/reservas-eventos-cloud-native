package cl.duoc.cloudnative.storage;

import java.io.IOException;
import java.time.LocalDate;
import java.util.Map;

import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/internal/storage")
public class StorageController {

    private final StorageService service;

    public StorageController(StorageService service) {
        this.service = service;
    }

    // CREAR ARCHIVO
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Map<String, String> store(
            @RequestPart("file") MultipartFile file,
            @RequestParam String clientId,
            @RequestParam LocalDate date) throws IOException {

        return service.store(file, clientId, date);
    }

    // ACTUALIZAR ARCHIVO
    @PutMapping(
            value = "/{clientId}/{date}/{filename:.+}",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public Map<String, String> update(
            @PathVariable String clientId,
            @PathVariable LocalDate date,
            @PathVariable String filename,
            @RequestPart("file") MultipartFile file) throws IOException {

        return service.update(file, clientId, date, filename);
    }

    // CONSULTAR HISTORIAL
    @GetMapping("/history/{clientId}")
    public Map<String, Object> history(
            @PathVariable String clientId,
            @RequestParam(required = false) LocalDate date) {

        return service.history(clientId, date);
    }

    // DESCARGAR ARCHIVO
    @GetMapping("/{clientId}/{date}/{filename:.+}")
    public ResponseEntity<byte[]> download(
            @PathVariable String clientId,
            @PathVariable LocalDate date,
            @PathVariable String filename) {

        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .body(service.load(clientId, date, filename));
    }
}