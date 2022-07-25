# Specify the Dart SDK base image version using dart:<version> (ex: dart:2.12)
FROM dart:stable AS build

# Resolve app dependencies.
WORKDIR /cardboard_bot
COPY pubspec.* ./
RUN dart pub get
RUN dart run build_runner build

# Copy app source code and AOT compile it.
COPY . .
# Ensure packages are still up-to-date if anything has changed
RUN dart pub get --offline
RUN dart compile exe bin/main.dart -o bin/main
# Build minimal serving image from AOT-compiled `/server` and required system
# libraries and configuration files stored in `/runtime/` from the build stage.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /cardboard_bot/bin/main /cardboard_bot/bin/
#COPY --from=build /cardboard_bot/configs/app_config.yaml /cardboard_bot/configs/
#COPY --from=build /cardboard_bot/configs/googleapis_service_account.json /cardboard_bot/configs/

# Start server.
#EXPOSE 8080
CMD ["/cardboard_bot/bin/main"]