package cl.duoc.cloudnative.documents;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.LocalDate;

public record CreateDocumentRequest(

    @NotBlank
    String userId,

    @NotBlank
    @Size(max = 80)
    String userName,

    @NotBlank
    String eventId,

    @NotBlank
    @Size(max = 120)
    String eventName,

    @NotNull
    LocalDate eventDate,

    @NotNull
    @DecimalMin("0.01")
    BigDecimal price

) {}