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
    PlayerFinishData(const string &in wsid, uint finishTime, uint position) {
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

void AddRoundTimeReq(const string &in matchId, const string &in payload) {
    MakeRequestEcircuit(URL_ADD_ROUND_TIME + matchId, payload);
}

void AddRoundReq(const string &in matchId, const string &in payload) {
    MakeRequestEcircuit(URL_ADD_ROUND_FULL + matchId, payload);
}


void MakeRequestEcircuit(const string &in url, const string &in payload) {
    Net::HttpRequest@ req = Net::HttpRequest();
    req.Method = Net::HttpMethod::Post;
    req.Url = url;
    print("Req: " + url);
    req.Body = payload;
    print("Payload: " + payload);
    req.Headers["Authorization"] = S_API_KEY;
    req.Headers["Content-Type"] = "application/json";
    req.Start();
    while (!req.Finished()) {
        yield();
    }
    if (req.ResponseCode() != 200) {
        print("Error: " + req.ResponseCode());
        print("Response: " + req.String());
    } else {
        print("Success: " + req.String());
    }
}
