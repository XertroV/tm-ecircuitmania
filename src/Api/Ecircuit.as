Json::Value@ MakePlayerFinishPayload(const string &in wsid, uint finishTime, uint trackNum, uint roundNum, const string &in mapUid) {
    Json::Value@ payload = Json::Object();
    payload["ubisoftUid"] = wsid;
    payload["finishTime"] = finishTime;
    payload["trackNum"] = trackNum;
    payload["roundNum"] = roundNum;
    payload["mapId"] = mapUid;
    payload["timestamp"] = Time::Stamp;
    return payload;
}

class PlayerFinishData {
    string wsid;
    uint finishTime;
    uint position;
    PlayerFinishData(const string &in wsid, int finishTime, int position) {
        this.wsid = wsid;
        this.finishTime = finishTime;
        this.position = position;
    }
}

// for cup send -1 for trackNum b/c no reliable source. for rounds send the trackNum from parsing
Json::Value@ MakeRoundEndPayload(array<PlayerFinishData@>@ players, uint trackNum, uint roundNum, const string &in mapUid) {
    Json::Value@ payload = Json::Object();
    Json::Value@ playersArray = Json::Array();
    for (uint i = 0; i < players.Length; i++) {
        Json::Value@ player = Json::Object();
        player["ubisoftUid"] = players[i].wsid;
        player["finishTime"] = players[i].finishTime;
        player["position"] = players[i].position;
        playersArray.Add(player);
    }
    payload["players"] = playersArray;
    payload["trackNum"] = trackNum;
    // payload["trackNum"] = -1;
    payload["roundNum"] = roundNum;
    payload["mapId"] = mapUid;
    payload["timestamp"] = Time::Stamp;
    return payload;
}

const string URL_ADD_ROUND_TIME = "https://us-central1-fantasy-trackmania.cloudfunctions.net/match-addRoundTime?matchId=";
const string URL_ADD_ROUND_FULL = "https://us-central1-fantasy-trackmania.cloudfunctions.net/match-addRound?matchId=";

ECMResponse@ AddOnPlayerFinishReq(const string &in apiKey, const string &in matchId, const string &in payload) {
    return MakeRequestEcircuit(apiKey, URL_ADD_ROUND_TIME + matchId, payload);
}

ECMResponse@ AddOnEndRoundReq(const string &in apiKey, const string &in matchId, const string &in payload) {
    return MakeRequestEcircuit(apiKey, URL_ADD_ROUND_FULL + matchId, payload);
}


ECMResponse@ MakeRequestEcircuit(const string &in apiKey, const string &in url, const string &in payload) {
    Net::HttpRequest@ req = Net::HttpRequest();
    req.Method = Net::HttpMethod::Post;
    req.Url = url;
    print("Req: " + url);
    req.Body = payload;
    print("Payload: " + payload);
    req.Headers["Authorization"] = apiKey;
    req.Headers["Content-Type"] = "application/json";
    req.Start();
    while (!req.Finished()) {
        yield();
    }
    string msg = req.String();
    int status = req.ResponseCode();
    if (status < 200 || status >= 300) {
        print("Status Code: " + status);
        print("Error: " + msg);
        return ECMResponse(false, status, msg);
    } else {
        print("Success: " + msg);
        return ECMResponse(true, status, msg);
    }
}

class ECMResponse {
    bool success;
    int status;
    string message;
    ECMResponse(bool success, int status, const string &in message) {
        this.success = success;
        this.status = status;
        this.message = message;
    }
}
