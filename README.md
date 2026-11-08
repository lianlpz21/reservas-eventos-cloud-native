# CDY2204 — Semana 3: solución Cloud Native de documentos comerciales

Proyecto docente de **Desarrollo Cloud Native**, Semana 3 (Experiencia de Aprendizaje 1), construido siguiendo el PDA724/CDY2204.

**Objetivo:** construir dos microservicios Java/Spring Boot que generan documentos comerciales PDF, usan **Amazon EFS como espacio temporal compartido**, almacenan los documentos definitivos en **Amazon S3**, y se publican/despliegan con **Docker Hub + GitHub Actions + Amazon EC2**.

> **Importante:** es un laboratorio educativo, **no un producto listo para producción**. El endpoint externo no implementa autenticación, las descargas se autorizan solo por ruta, el puerto 8080 utiliza HTTP sin TLS, y el directorio EFS admite escritura en el entorno docente. Restringir estrictamente la CIDR, no utilizar datos reales de clientes y revisar las recomendaciones de endurecimiento antes de cualquier uso real.

## 1. Componentes

```text
Cliente HTTP
     │ POST /api/documents  (datos JSON)
     ▼
 document-service (Spring Boot :8080)
     │  1. Genera PDF mediante Apache PDFBox
     │  2. Envía multipart/form-data al servicio interno
     ▼
 storage-service (Spring Boot :8081, sin puerto público)
     │  3. Crea archivo PDF temporal en volumen EFS
     │  4. Publica objeto en S3 con AWS SDK v2
     │  5. Elimina archivo temporal del volumen EFS
     ▼
 Amazon S3: clientes/{cliente}/{año}/{mes}/{día}/documento-{UUID}.pdf
     ▲
     └── GET /api/documents/{cliente}/{fecha}/{archivo} → S3 → PDF

GitHub push → GitHub Actions → Maven + JUnit → Docker Hub (2 imágenes)
          → GitHub OIDC → AWS Systems Manager → Docker Compose en EC2

EC2: perfil IAM para S3 y SSM; volumen EFS montado vía NFS en VPC.
```

El archivo temporal en EFS se elimina después de subirlo correctamente. Si la subida falla también se limpia el temporal en `finally`. Este diseño muestra el **ciclo de vida de los documentos** sin usar EFS para almacenamiento definitivo.

## 2. Correspondencia con los indicadores del PDA

| Indicador | Implementación | Evidencia que puede mostrar el estudiante |
|---|---|---|
| **IL1** CI/CD | `.github/workflows/cicd.yml`: build, tests, Docker | Ejecución exitosa y 2 imágenes Docker Hub |
| **IL2** despliegue automático | Job `deploy`, OIDC, SSM, Compose EC2 | GitHub Actions + contenedores actualizados en EC2 |
| **IL3** configuración almacenamiento | Terraform EFS + mount targets + S3 privado/cifrado/versionado/IAM | EFS montado, bucket privado y política limitada |
| **IL4** Java gestiona archivos | 2 servicios Spring Boot; PDFBox, EFS temporal y AWS SDK S3 | API genera y recupera PDF, objeto estructurado en S3 |

**Límites:** se implementan los componentes solicitados, pero la conformidad final depende de la pauta detallada de evaluación en AVA, que no fue entregada. La solución no sustituye evidencia de despliegue real.

## 3. Prerrequisitos

- Java 17, Maven 3.9+ y Docker Engine con Docker Compose v2 para entorno local.
- Cuenta AWS con permisos para EC2, IAM, S3, EFS, VPC, Systems Manager y OIDC; AWS CLI y Terraform >= 1.6 para despliegue Cloud.
- GitHub y Docker Hub, con dos repositorios de imagen **públicos** `cloudnative-documents` y `cloudnative-storage`. Si son privados, configurar login del host EC2 con un token de lectura protegido antes del despliegue.
- VPC por defecto con subredes y salida a Internet; esta plantilla usa la VPC por defecto para reducir infraestructura. Si la cuenta no tiene VPC por defecto, adapta la configuración antes de aplicar Terraform.

## 4. Ejecutar localmente — S3 emulado y EFS simulado

**Advertencia:** el laboratorio local utiliza **LocalStack para emular S3** y una carpeta `./.local/efs` que **simula el punto de montaje EFS**. No prueba un EFS real. Para cumplir IL3 debes desplegar en AWS.

```bash
mvn -B clean verify
mkdir -p .local/efs
chmod 777 .local/efs       # solo local, con datos ficticios
docker compose -f docker-compose.local.yml up -d --build
curl http://localhost:8080/api/health
bash scripts/demo.sh
```

`bash scripts/build-local.sh` hace estas acciones automáticamente. LocalStack utiliza credenciales ficticias `test`, que no deben trasladarse a AWS.

### Solicitud para generar documento

```bash
curl -sS -X POST http://localhost:8080/api/documents \
  -H 'Content-Type: application/json' \
  -d '{"clientId":"cliente123","clientName":"Comercial Demo","concept":"Servicio de soporte","amount":35000,"date":"2026-11-04"}'
```

**Respuesta esperada (ejemplo, el UUID cambia):**

```json
{
  "clientId": "cliente123",
  "date": "2026-11-04",
  "filename": "documento-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.pdf",
  "s3Key": "clientes/cliente123/2026/11/04/documento-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.pdf",
  "storage": "S3",
  "temporaryStorage": "EFS"
}
```

Usa los valores reales de `clientId`, `date` y `filename` para descargar por `GET /api/documents/{clientId}/{date}/{filename}`. En local, el campo `temporaryStorage` describe el diseño: el volumen es una **simulación de EFS**.

Comprobar S3 local:

```bash
docker compose -f docker-compose.local.yml exec localstack \
  awslocal s3 ls s3://cloudnative-docs-local/ --recursive
```

Comprobar temporales:

```bash
docker compose -f docker-compose.local.yml exec storage ls -la /mnt/efs
```

No deberían quedar PDFs temporales después de una solicitud exitosa.

## 5. Despliegue en AWS con Terraform

**Antes de empezar:** los recursos AWS generan costos incluso sin peticiones. EC2, EFS, direcciones IPv4 públicas, almacenamiento S3 y transferencia de datos pueden facturar. No hay garantía de gratuidad. Borra los recursos al finalizar, tras respaldar datos si corresponde.

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Editar IP pública /32 y ruta propietario/repositorio de GitHub.
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
terraform output
```

Terraform crea: bucket S3 privado con cifrado y versionado, EFS cifrado con un mount target por AZ de la VPC, EC2 Amazon Linux 2023, security groups (NFS solo desde la EC2), instance profile S3/SSM, proveedor OIDC de GitHub y rol restringido de despliegue, y un bootstrap EC2 que instala Docker/Compose y monta EFS en `/mnt/efs`.

**Notas de AWS:**

- Debes usar una IP pública propia como `allowed_api_cidr` (por ejemplo `/32`). **No** habilites `0.0.0.0/0`.
- EC2 necesita salida a Internet para instalar Docker Compose, obtener imágenes y comunicarse con SSM; esta plantilla asume que la VPC y la ruta de la subred lo permiten.
- La cuenta no debe tener ya creado el proveedor OIDC de `https://token.actions.githubusercontent.com`. Si existe, debes **importarlo al estado** o reutilizarlo como `data source`, para evitar un error de duplicidad.
- El rol IAM de EC2 permite `s3:GetObject` y `s3:PutObject` solamente dentro de `clientes/*` del bucket creado.
- En AWS, verificar que SSM Agent esté en línea, que el montaje EFS tenga permisos y que `docker compose version` funcione.
- Los registros de bootstrap quedan en `/var/log/cdy2204-bootstrap.log` en EC2.
- **No ejecutar `terraform destroy` si existen documentos reales**: el bucket no permite destrucción forzada.

## 6. Configurar GitHub Actions

Publicar este contenido en un repositorio nuevo cuyo nombre corresponda a `github_repo` de Terraform. Crear un GitHub **Environment** `aws-demo` en *Settings → Environments*; se recomienda agregar aprobaciones obligatorias y restringir despliegues a la rama `main`.

Configurar las siguientes variables (**Settings → Secrets and variables → Actions → Variables**):

| Variable | Valor |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Output Terraform `aws_deploy_role_arn` |
| `AWS_REGION` | Output `region` |
| `EC2_INSTANCE_ID` | Output `ec2_instance_id` |
| `S3_BUCKET` | Output `s3_bucket` |

Secrets:

| Secreto | Valor |
|---|---|
| `DOCKERHUB_USERNAME` | Usuario Docker Hub |
| `DOCKERHUB_TOKEN` | Access token de Docker Hub (preferentemente token de alcance reducido) |

A continuación realizar `git push` a `main` o iniciar `workflow_dispatch`. Se ejecutarán:

1. `mvn clean verify` y subida de dos JAR como artefactos temporales;
2. Publicación de `usuario/cloudnative-documents:<commit>` y `usuario/cloudnative-storage:<commit>` en Docker Hub;
3. Asunción de rol IAM con GitHub OIDC y actualización remota con Systems Manager;
4. `docker compose pull && docker compose up -d` y chequeo de salud vía HTTP en la instancia.

**Importante:** el job de despliegue requiere Docker Hub público; con imágenes privadas hay que diseñar una autenticación segura adicional en EC2. Si `deploy` falla por SSM, revisar permisos, salida a red y estado del agente. No se utiliza SSH.

## 7. Validar la demostración en AWS

```bash
# Reemplazar con la IPv4 pública de Terraform (acceso solo desde IP autorizada).
curl http://EC2_PUBLIC_IP:8080/api/health
bash scripts/demo.sh http://EC2_PUBLIC_IP:8080

# Verificar el objeto generado desde AWS CLI con tus credenciales autorizadas.
aws s3 ls s3://NOMBRE_BUCKET/clientes/ --recursive
```

Evidencias que se pueden capturar: workflow verde, dos imágenes en Docker Hub, `aws s3 ls` con clave por cliente y fecha, instancia EC2 registrada en SSM, EFS montado, API respondiendo y PDF descargado.

## 8. Guion de demostración (90 min)

| Minutos | Actividad |
|---|---|
| 0–10 | Propósito, RA1 y cuatro indicadores |
| 10–25 | Arquitectura: diferencias EFS vs S3, IAM y almacenamiento temporal |
| 25–45 | Generar PDF con `document-service` e integración con `storage-service` |
| 45–70 | Maven, tests, Dockerfile, workflow GitHub Actions y Docker Hub |
| 70–85 | Revisión de EC2, SSM, EFS, S3 y demostración end-to-end |
| 85–90 | Resumen de IL1–IL4 y evidencias de la sumativa |

## 9. Riesgos y mejoras sugeridas

- **No es producción:** incorporar autenticación/autorización por cliente, TLS mediante ALB+ACM, validación de cuotas, rate limiting, observabilidad, escaneo de imágenes, auditoría de descargas, políticas de retención y pruebas de integración cloud.
- EFS en esta plantilla se monta a través de `amazon-efs-utils` y se deja escribible para simplificar el laboratorio. Usar EFS Access Points/UID/GID mínimos en escenarios reales.
- No se conserva metadata de facturas en una base de datos; se gestionan los PDFs directamente mediante claves S3. La especificación de Semana 3 no exige una BD.
- No se integra API Manager/IDaaS ni mensajería asíncrona: estos corresponden a las Experiencias 2 y 3, no a Semana 3.
- La infraestructura debe ser validada y desplegada en tu propia cuenta AWS. La disponibilidad real de componentes/regiones, cuotas, políticas organizacionales, bootstrap de EC2 y permisos de AWS no se pueden garantizar desde este archivo.

## 10. Limpieza

```bash
docker compose -f docker-compose.local.yml down -v
# AWS: primero eliminar manualmente documentos/versiones si decides borrarlos,
# revisar todos los recursos y luego:
cd infra/terraform && terraform destroy
```

---

Fuente curricular: `PDA724_CDY2204.docx`, Semana 3, páginas 28–30; `PIA724_CDY2204`, RA1 e IL1–IL4. **Revisar pauta específica del AVA antes de evaluar estudiantes.**
