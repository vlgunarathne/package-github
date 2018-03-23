//
// Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

package github;

import ballerina.net.http;
import ballerina.mime;

@Description {value:"Construct the request headers"}
@Param {value:"request: The http request object"}
@Param {value:"query: GraphQL API query"}
@Param {value:"accessToken: GitHub access token"}
function constructRequest (http:Request request, json stringQuery, string accessToken) {
    gitAccessToken = accessToken;
    request.removeAllHeaders();
    request.addHeader("Authorization", "Bearer " + accessToken);
    request.setJsonPayload(stringQuery);

}

@Description {value:"Validate the http response"}
@Param {value:"http:Response: The http response object"}
@Param {value:"component:"}
@Return {value:"json: The JSON payload in the response"}
@Return {value:"GitConnectoError: GitConnectorError object"}
function getValidatedResponse (http:Response|http:HttpConnectorError response, string validateComponent) returns json|GitConnectorError {
    GitConnectorError connectorError = {};
    json responsePayload;

    match response {
        http:Response gitResponse => {
            try {
                var jsonPayload = gitResponse.getJsonPayload();

                match jsonPayload {
                    json jsonData => {
                        responsePayload = jsonData;
                    }
                    mime:EntityError entityError => {
                        connectorError = {message:[entityError.message]};
                        return connectorError;
                    }
                }
                string[] payLoadKeys = responsePayload.getKeys();
                //Check all the keys in the payload to see if an error object is returned.
                foreach key in payLoadKeys {
                    if (GIT_ERRORS.equalsIgnoreCase(key)){
                        string[] errors = [];
                        var errorList =? <json[]>responsePayload[GIT_ERRORS];
                        foreach i, singleError in errorList {
                            errors[i] =? <string>singleError[GIT_MESSAGE];
                        }
                        connectorError = {message:errors, statusCode:gitResponse.statusCode, reasonPhrase:gitResponse.reasonPhrase, server:gitResponse.server};
                        return connectorError;
                    }
                }
                //If no error object is returned, then check if the response contains the requested data.
                string keyInData = responsePayload[GIT_DATA].getKeys()[GIT_INDEX_ZERO];
                if (null == responsePayload[GIT_DATA][keyInData][validateComponent]) {
                    string[] errorMessage = [GIT_ERROR_WHILE_RETRIEVING_DATA];
                    responsePayload = null;
                    connectorError = {message:errorMessage, statusCode:gitResponse.statusCode, reasonPhrase:gitResponse.reasonPhrase, server:gitResponse.server};
                    return connectorError;
                }


            } catch (error e) {
                string[] errorMessage = [GIT_ERROR_WHILE_RETRIEVING_PAYLOAD];
                responsePayload = null;
                connectorError = {message:errorMessage, statusCode:gitResponse.statusCode, reasonPhrase:gitResponse.reasonPhrase, server:gitResponse.server};
                return connectorError;
            }
        }

        http:HttpConnectorError httpError => {
            connectorError = {message:[httpError.message], statusCode:httpError.statusCode};
            return connectorError;
        }
    }
    

    return responsePayload;

}