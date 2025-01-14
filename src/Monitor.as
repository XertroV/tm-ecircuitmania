enum RaceState {
    NoMap,
    // Invalid game time, intro ui seq, warmup, etc.
    NoRound_or_Warmup,
    // EndRound, UISequence
    EndRound_or_Similar,
    // Playing, Finish, ppl are racing
    Active,
    Podium
}


class RaceMonitor {
    uint lastMapMwId = uint(-1);
    int currRound = 0;
    int currMap = 0;
    bool KeepRunning = true;
    RaceState currState = RaceState::NoMap;
    string matchId;
    string apiKey;

    RaceMonitor(const string &in matchId, const string &in apiKey, int startRound = 0, int startMap = 0) {
        // startnew(CoroutineFunc(RunMonitor));
        currRound = startRound;
        currMap = startMap;
        this.matchId = matchId;
        this.apiKey = apiKey;
    }

    ~RaceMonitor() {
        Shutdown();
    }

    void Shutdown() {
        KeepRunning = false;
    }

    array<const MLFeed::PlayerCpInfo_V4@> startedPlayers;
    uint[] startedPlayerLoginIds;
    array<const MLFeed::PlayerCpInfo_V4@> finishedPlayers;
    uint[] finishedPlayerLoginIds;

    void ClearFinishedPlayers() {
        finishedPlayers.RemoveRange(0, finishedPlayers.Length);
        finishedPlayerLoginIds.RemoveRange(0, finishedPlayerLoginIds.Length);
        startedPlayers.RemoveRange(0, startedPlayers.Length);
        startedPlayerLoginIds.RemoveRange(0, startedPlayerLoginIds.Length);
    }

    void ClearFinishedPlayers_Delayed() {
        yield();
        ClearFinishedPlayers();
    }

    bool HasPlayerFinished(uint loginIdVal) {
        return finishedPlayerLoginIds.Find(loginIdVal) >= 0;
    }

    void Update() {
        auto newState = CalcState();
        if (newState != currState) {
            UpdateState(currState, newState);
        }
        if (NewMapThisFrame) OnNewMap();
        if (currState == RaceState::Active) {
            UpdateActive();
        }
    }

    void OnNewMap() {
        ClearFinishedPlayers();
        currMap++;
        currRound = 0;
    }

    RaceState CalcState() {
        if (!IsPgLoaded) return RaceState::NoMap;
        auto rd = MLFeed::GetRaceData_V4();
        if (rd.Rules_StartTime < 0 || (rd.Rules_EndTime > 0 && rd.Rules_StartTime >= rd.Rules_EndTime)) return RaceState::NoRound_or_Warmup;
        if (rd.WarmupActive) return RaceState::NoRound_or_Warmup;
        auto app = cast<CGameManiaPlanet>(GetApp());
        auto seq = int(app.CurrentPlayground.GameTerminals[0].UISequence_Current);
        if (IsEndRoundUISeq(seq)) return RaceState::EndRound_or_Similar;
        if (IsPlayingUISeq(seq)) return RaceState::Active;
        if (IsPodiumUISeq(seq)) return RaceState::Podium;
        return RaceState::NoRound_or_Warmup;
    }


    void UpdateState(RaceState old, RaceState new) {
        currState = new;
        switch (new) {
            case RaceState::NoMap: return;
            case RaceState::NoRound_or_Warmup: {
                OnWarmup(old);
                return;
            }
            case RaceState::EndRound_or_Similar: {
                OnEndRound(old);
                return;
            }
            case RaceState::Active: {
                OnGoingActive(old);
                return;
            }
            case RaceState::Podium: {
                OnPodium(old);
                return;
            }
        }
    }

    void OnWarmup(RaceState prior) {
        if (prior == RaceState::Active) {
            if (Time::Now - lastWentActive < 2000) {
                // ignore this round, probably just before warmup
                currRound = Math::Max(0, currRound - 1);
            }
        }
        Dev_Notify("OnWarmup, prior: " + tostring(prior));
    }

    uint lastWentActive;
    void UpdateActive() {
        lastWentActive = Time::Now;
        auto rd = MLFeed::GetRaceData_V4();
        for (uint i = 0; i < rd.SortedPlayers_Race.Length; i++) {
            auto player = cast<MLFeed::PlayerCpInfo_V4>(rd.SortedPlayers_Race[i]);
            if (player.IsSpawned && player.IsFinished && !HasPlayerFinished(player.LoginMwId.Value)) {
                AddPlayerFinish(player);
            }
        }
    }

    void AddPlayerFinish(const MLFeed::PlayerCpInfo_V4@ player) {
        if (HasPlayerFinished(player.LoginMwId.Value)) {
            Dev_Notify("Player already finished: " + player.Login);
            return;
        }
        finishedPlayers.InsertLast(player);
        finishedPlayerLoginIds.InsertLast(player.LoginMwId.Value);
        startnew(CoroutineFuncUserdata(SendPlayerFinish), player);
    }

    void SendPlayerFinish(ref@ pref) {
        MLFeed::PlayerCpInfo_V4@ player = cast<MLFeed::PlayerCpInfo_V4>(pref);
        PlayerFinishMsgs_Sent++;
        ECMResponse@ r = AddOnPlayerFinishReq(apiKey, matchId, Json::Write(MakePlayerFinishPayload(player.WebServicesUserId, player.IsFinished ? player.LastCpTime : -1, currMap, currRound, mapUid)));
        if (r.success) {
            PlayerFinishMsgs_Succeeded++;
            lastSuccessMsg = r.message;
        } else {
            PlayerFinishMsgs_Failed++;
            lastError = r.message;
        }
    }

    void OnGoingActive(RaceState prior) {
        ClearFinishedPlayers();
        if (prior == RaceState::NoMap) {
            if (currMap == 0) currMap = 1;
            if (currRound == 0) currRound = 1;
        } else if (prior != RaceState::Active) {
            currRound++;
        }
        Dev_Notify("OnGoingActive, prior: " + tostring(prior));
        startnew(CoroutineFunc(CacheStartedPlayers_Delayed));
    }

    void CacheStartedPlayers_Delayed() {
        auto start = Time::Now;
        while (currState == RaceState::Active && Time::Now < start + 2000) {
            yield();
        }
        if (currState != RaceState::Active) return;

        auto rd = MLFeed::GetRaceData_V4();
        for (uint i = 0; i < rd.SortedPlayers_Race.Length; i++) {
            auto player = cast<MLFeed::PlayerCpInfo_V4>(rd.SortedPlayers_Race[i]);
            if (startedPlayerLoginIds.Find(player.LoginMwId.Value) >= 0) continue;
            if (player.SpawnStatus == MLFeed::SpawnStatus::NotSpawned) continue;
            startedPlayers.InsertLast(player);
            startedPlayerLoginIds.InsertLast(player.LoginMwId.Value);
        }
    }

    void OnEndRound(RaceState prior) {
        if (prior == RaceState::Active) {
            startnew(CoroutineFunc(SendOnRoundEnd));
        } else {
        }
        startnew(CoroutineFunc(ClearFinishedPlayers_Delayed));
        Dev_Notify("OnEndRound, prior: " + tostring(prior));
    }

    void OnPodium(RaceState prior) {
        Dev_Notify("OnPodium, prior: " + tostring(prior));
    }



    uint RoundEndMsgs_Sent = 0;
    uint RoundEndMsgs_Succeeded = 0;
    uint RoundEndMsgs_Failed = 0;

    uint PlayerFinishMsgs_Sent = 0;
    uint PlayerFinishMsgs_Succeeded = 0;
    uint PlayerFinishMsgs_Failed = 0;

    uint lastReqStatus = 0;
    string lastSuccessMsg = "";
    string lastError = "";

    void SendOnRoundEnd() {
        RoundEndMsgs_Sent++;
        ECMResponse@ r = AddOnEndRoundReq(apiKey, matchId, Json::Write(GetRoundEndPayload()));
        if (r.success) {
            RoundEndMsgs_Succeeded++;
            lastSuccessMsg = r.message;
        } else {
            RoundEndMsgs_Failed++;
            lastError = r.message;
        }
    }

    Json::Value@ GetRoundEndPayload() {
        auto rd = MLFeed::GetRaceData_V4();
        PlayerFinishData@[] players;
        for (uint i = 0; i < finishedPlayers.Length; i++) {
            auto player = finishedPlayers[i];
            players.InsertLast(PlayerFinishData(player.WebServicesUserId, player.IsFinished ? player.LastCpTime : -1, i + 1));
        }
        auto nbFinished = players.Length;
        for (uint i = 0; i < rd.SortedPlayers_Race.Length; i++) {
            auto player = cast<MLFeed::PlayerCpInfo_V4>(rd.SortedPlayers_Race[i]);
            if (player.RequestsSpectate) continue;
            if (player.CpCount == 0) continue;
            if (finishedPlayerLoginIds.Find(player.LoginMwId.Value) >= 0) continue;
            players.InsertLast(PlayerFinishData(player.WebServicesUserId, player.IsFinished ? player.LastCpTime : -1, ++nbFinished));
            finishedPlayerLoginIds.InsertLast(player.LoginMwId.Value);
        }
        for (uint i = 0; i < startedPlayers.Length; i++) {
            auto player = startedPlayers[i];
            if (player.RequestsSpectate) continue;
            if (player.CpCount == 0) continue;
            if (finishedPlayerLoginIds.Find(player.LoginMwId.Value) >= 0) continue;
            players.InsertLast(PlayerFinishData(player.WebServicesUserId, -1, ++nbFinished));
            finishedPlayerLoginIds.InsertLast(player.LoginMwId.Value);
        }
        return MakeRoundEndPayload(players, currMap, currRound, mapUid);
    }


    void DrawWindowInner() {
        UI::AlignTextToFramePadding();
        UI::Text("Running Monitor");
        DrawRoundAndMap();
        UI::Separator();
        DrawCurrentState();
        UI::Separator();
        UI::PushStyleColor(UI::Col::Header, vec4(0.260f, 0.590f, 0.980f, 0.304f) * .5);
        if (UI::CollapsingHeader("API Requests Info")) {
            DrawRequestsInfo();
        }
        UI::PopStyleColor();
    }

    void DrawRequestsInfo() {
        UI::Text("RoundEnd Messages Sent: " + RoundEndMsgs_Sent);
        UI::Text("RoundEnd Messages Succeeded: " + RoundEndMsgs_Succeeded);
        UI::Text("RoundEnd Messages Failed: " + RoundEndMsgs_Failed);
        UI::Text("PlayerFinish Messages Sent: " + PlayerFinishMsgs_Sent);
        UI::Text("PlayerFinish Messages Succeeded: " + PlayerFinishMsgs_Succeeded);
        UI::Text("PlayerFinish Messages Failed: " + PlayerFinishMsgs_Failed);
        UI::Text("Last Request Status: " + lastReqStatus);
        UI::Text("Last Success Message: " + lastSuccessMsg);
        UI::Text("Last Error: " + lastError);
    }

    void DrawCurrentState() {
        UI::AlignTextToFramePadding();
        UI::Text("Current State: " + tostring(currState));
        UI::AlignTextToFramePadding();
        UI::Text("ECM Match ID: " + matchId);
        DrawStopMonitoringButton();
    }

    void DrawRoundAndMap() {
        UI::AlignTextToFramePadding();
        UI::Text("Round: " + currRound);
        UI::SameLine();
        UI::SetCursorPos(vec2(140, UI::GetCursorPos().y));
        if (UI::Button(Icons::Minus + " 1##subround")) {
            currRound--;
        }
        UI::SameLine();
        if (UI::Button(Icons::Plus + " 1##addround")) {
            currRound++;
        }

        UI::AlignTextToFramePadding();
        UI::Text("Map: " + currMap);
        UI::SameLine();
        UI::SetCursorPos(vec2(140, UI::GetCursorPos().y));
        if (UI::Button(Icons::Minus + " 1##submap")) {
            currMap--;
        }
        UI::SameLine();
        if (UI::Button(Icons::Plus + " 1##addmap")) {
            currMap++;
        }
    }
}


uint GetMapMwIdValue() {
    auto map = GetApp().RootMap;
    if (map is null) return 0xFFFFFFFF;
    return map.Id.Value;
}



bool IsPlayingUISeq(int seq) {
    return seq == int(CGamePlaygroundUIConfig::EUISequence::Playing)
        || seq == int(CGamePlaygroundUIConfig::EUISequence::Finish);
}

bool IsPodiumUISeq(int seq) {
    return seq == int(CGamePlaygroundUIConfig::EUISequence::Podium);
}

bool IsEndRoundUISeq(int seq) {
    return seq == int(CGamePlaygroundUIConfig::EUISequence::EndRound)
        || seq == int(CGamePlaygroundUIConfig::EUISequence::UIInteraction);
}
