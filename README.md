# opentelemetry-collector
A tool for building a custom OpenTelemetry collector image

## Building new image
A new version of the collector image can be configured in `resources/builder-config.yaml`

Inside that file, you can add new exporters, processors, receivers and extensions

To deploy the new image to ECR, merge changes into `main` branch and deploy via concourse pipeline