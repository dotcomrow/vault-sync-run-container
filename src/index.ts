import express, { Express, Request, Response } from "express";
import Handlers from "./handler.js"
import { serializeError } from "serialize-error";
import { GCPLogger } from "npm-gcp-logging";
import { GCPAccessToken } from "npm-gcp-token";
import axios from "axios";

const app: Express = express();
const port = process.env.PORT || 8080;

app.use(express.json()) 

app.post("/", async (req: Request, res: Response) => {
  const auth_header = req.header("Authorization");
  
  if (!auth_header) {
    res.status(401).send({
      message: "Unauthorized"
    });
    return;
  }

  const bearer_token = auth_header.split(" ")[1];
  var response = await axios.get("https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=" + bearer_token);

  if (response.data.error) {
    res.status(401).send({
      message: "Unauthorized"
    });
    return;
  }

  if (response.data.email != process.env.SHARED_SERVICE_ACCOUNT_EMAIL) {
    res.status(401).send({
      message: "Unauthorized"
    });
    return;
  }

  try {
    const { status, body } = await Handlers.handleRequest(req.body, response.data);
    res.status(status).setHeader(
      "Content-Type", "application/json"
    ).send(body);
  } catch (e) {
    if (!process.env.GCP_LOGGING_CREDENTIALS) {
      console.log("GCP_LOGGING_CREDENTIALS is not defined");
      res.status(500).send({
        message: "GCP_LOGGING_CREDENTIALS is not defined"
      });
      return;
    }
    
    if (!process.env.GCP_LOGGING_PROJECT_ID) {
      console.log("GCP_LOGGING_PROJECT_ID is not defined");
      res.status(500).send({
        message: "GCP_LOGGING_PROJECT_ID is not defined"
      });
      return;
    }

    if (!process.env.K_SERVICE) {
      console.log("K_SERVICE is not defined");
      res.status(500).send({
        message: "K_SERVICE is not defined"
      });
      return;
    }

    var logging_token = await new GCPAccessToken(
      process.env.GCP_LOGGING_CREDENTIALS
    ).getAccessToken("https://www.googleapis.com/auth/logging.write");
    const responseError = serializeError(e);
      await GCPLogger.logEntry(
        process.env.GCP_LOGGING_PROJECT_ID,
        logging_token.access_token,
        process.env.K_SERVICE,
        [
          {
            severity: "ERROR",
            // textPayload: message,
            jsonPayload: {
              responseError,
            },
          },
        ]
      );
    res.status(500).send({
      message: "Internal Server Error"
    });
    return;
  }
});

app.listen(port, () => {
  console.log(`[server]: Server is running at http://localhost:${port}`);
});