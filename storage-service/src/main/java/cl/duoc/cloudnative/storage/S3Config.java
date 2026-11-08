package cl.duoc.cloudnative.storage;
import java.net.URI;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
@Configuration public class S3Config {
 @Bean S3Client s3Client(@Value("${aws.region:us-east-1}") String region,
  @Value("${aws.s3.endpoint:}") String endpoint) {
  software.amazon.awssdk.services.s3.S3ClientBuilder builder=S3Client.builder().region(Region.of(region));
  if (!endpoint.isBlank()) builder.endpointOverride(URI.create(endpoint))
   .serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(true).build());
  return builder.build();
 }
}
