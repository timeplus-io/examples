import type { CreateQueryRequestV1Beta2 } from "./swagger";
import { Env } from "./env";
// @ts-ignore
import { fetchEventSource } from "@fortaine/fetch-event-source";

export const createQueryV1beta2 = async (
  queryRequest: CreateQueryRequestV1Beta2,
  fetchOptions: any
) => {
  try {
    const header = Env().AuthHeader();
    console.log("header is " + JSON.stringify(header));
    await fetchEventSource(Env().BuildUrl("v1beta2", "queries"), {
      method: "POST",
      mode: "cors",
      headers: Env().AuthHeader(),
      body: JSON.stringify(queryRequest),
      async onopen(response) {
        if (
          response.ok &&
          response.headers.get("content-type") === "text/event-stream"
        ) {
          return; // everything's good
        } else {
          const errorMessage = await response.text();
          throw `${response.status}: ${errorMessage}`;
        }
      },
      ...fetchOptions,
      openWhenHidden: true,
    });
  } catch (error: any) {
    if (fetchOptions.onerror) {
      fetchOptions.onerror(error);
      return;
    } else {
      console.error("sse failed");
    }
  }
};
