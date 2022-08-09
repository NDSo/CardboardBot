# Specify the Dart SDK base image version using dart:<version> (ex: dart:2.12)
FROM dart:stable AS heavy_base_image

# Resolve app dependencies.
WORKDIR /cardboard_bot
COPY pubspec.* ./
RUN dart pub get

# Copy app source code and AOT compile it.
COPY . .
# Ensure packages are still up-to-date if anything has changed
RUN dart pub get --offline
RUN dart run build_runner build
RUN dart compile exe bin/main.dart -o bin/main

# Build minimal serving image from AOT-compiled `/server` and required system
# libraries and configuration files stored in `/runtime/` from the build stage.
FROM scratch as minimal_image
COPY --from=heavy_base_image /runtime/ /
COPY --from=heavy_base_image /cardboard_bot/bin/main /cardboard_bot/bin/

# Start server.
ENTRYPOINT ["/cardboard_bot/bin/main"]



######### LOCAL DEPLOYMENT
FROM minimal_image as local_development_image

COPY --from=heavy_base_image /cardboard_bot/configs/app_config.yaml /cardboard_bot/configs/

# Custom Arguments
CMD []

######## CLOUD DEVELOPMENT
FROM minimal_image as local_cloud_development_image

COPY --from=heavy_base_image /cardboard_bot/configs/googleapis_service_account.json /cardboard_bot/configs/

# Custom Arguments
CMD ["--google_cloud_project_id", "cardboardbot-f4c69"]

######### CLOUD DEPLOYMENT
FROM minimal_image as remote_cloud_production_image

# Custom Arguments
CMD ["--google_cloud_project_id", "cardboardbot-f4c69"]