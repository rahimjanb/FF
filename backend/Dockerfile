FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY src/FitnessFormulasi.Api/FitnessFormulasi.Api.csproj src/FitnessFormulasi.Api/
RUN dotnet restore src/FitnessFormulasi.Api/FitnessFormulasi.Api.csproj
COPY src/ src/
RUN dotnet publish src/FitnessFormulasi.Api -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
# Uploaded banner media (Media__RootPath); a named volume mounted here keeps this owner.
RUN mkdir -p /data/media && chown $APP_UID /data/media
USER $APP_UID
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "FitnessFormulasi.Api.dll"]
