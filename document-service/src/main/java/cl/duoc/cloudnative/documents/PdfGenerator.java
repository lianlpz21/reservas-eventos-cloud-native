package cl.duoc.cloudnative.documents;

import org.apache.pdfbox.pdmodel.*;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.*;
import org.springframework.stereotype.Service;

import java.io.*;
import java.text.Normalizer;

@Service
public class PdfGenerator {

    public byte[] generate(CreateDocumentRequest request) throws IOException {

        try (PDDocument pdf = new PDDocument();
             ByteArrayOutputStream output = new ByteArrayOutputStream()) {

            PDPage page = new PDPage(PDRectangle.A4);
            pdf.addPage(page);

            try (PDPageContentStream content = new PDPageContentStream(pdf, page)) {

                content.beginText();
                content.setFont(
                    new PDType1Font(Standard14Fonts.FontName.HELVETICA_BOLD), 17
                );
                content.newLineAtOffset(55, 760);
                content.showText("TICKET DE EVENTO");
                content.endText();

                String[] rows = {
                    "Usuario ID: " + request.userId(),
                    "Usuario: " + request.userName(),
                    "Evento ID: " + request.eventId(),
                    "Evento: " + request.eventName(),
                    "Fecha del evento: " + request.eventDate(),
                    "Precio: $" + request.price().toPlainString()
                };

                int y = 715;

                for (String row : rows) {
                    content.beginText();
                    content.setFont(
                        new PDType1Font(Standard14Fonts.FontName.HELVETICA), 12
                    );
                    content.newLineAtOffset(55, y);
                    content.showText(safeText(row));
                    content.endText();

                    y -= 30;
                }
            }

            pdf.save(output);
            return output.toByteArray();
        }
    }

    private String safeText(String s) {
        String normalized = Normalizer
            .normalize(s, Normalizer.Form.NFD)
            .replaceAll("\\p{M}", "");

        return normalized.replaceAll("[^ -~]", "?");
    }
}