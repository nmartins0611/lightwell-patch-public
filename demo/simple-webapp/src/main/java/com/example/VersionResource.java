package com.example;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.config.inject.ConfigProperty;

@Path("/")
public class VersionResource {

    @ConfigProperty(name = "quarkus.application.version")
    String version;

    @ConfigProperty(name = "demo.gson.version")
    String gsonVersion;

    @GET
    @Produces(MediaType.TEXT_HTML)
    public String index() {
        return """
            <html>
              <head><title>simple-webapp</title></head>
              <body>
                <h1>simple-webapp</h1>
                <p>Version %s</p>
                <p>gson %s</p>
              </body>
            </html>
            """.formatted(version, gsonVersion);
    }

    @GET
    @Path("/version")
    @Produces(MediaType.APPLICATION_JSON)
    public String version() {
        JsonObject body = new JsonObject();
        body.addProperty("service", "simple-webapp");
        body.addProperty("version", version);
        body.addProperty("gson_version", gsonVersion);
        return new Gson().toJson(body);
    }
}
