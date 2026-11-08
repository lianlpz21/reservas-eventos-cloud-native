package cl.duoc.cloudnative.documents;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.time.LocalDate;
import static org.junit.jupiter.api.Assertions.*;
class PdfGeneratorTest {
 @Test void generatesPdf() throws Exception {
  byte[] bytes=new PdfGenerator().generate(new CreateDocumentRequest("cliente01","Comercial Ejemplo","Servicio",new BigDecimal("25000"),LocalDate.of(2026,11,4)));
  assertTrue(bytes.length>200);
  assertEquals("%PDF-",new String(bytes,0,5,java.nio.charset.StandardCharsets.US_ASCII));
 }
}
