void Main() {

}


void Render() {
    // if (UI::Begin("Ecircuit Test")) {
    //     if (UI::Button("Test req 1")) {
    //         startnew(TestReq1);
    //     }
    //     if (UI::Button("Test req 1a")) {
    //         startnew(TestReq1a);
    //     }
    //     if (UI::Button("Test req 2")) {
    //         startnew(TestReq2);
    //     }
    // }
    // UI::End();
}



void TestReq1() {
    auto finPl = MakePlayerFinishPayload("0782eabd-e9ce-473b-a293-c1dd846e749b", 12354, 7, 2, "4TN4MeQNwtr161g31CybCw9NKAa"+Time::Now);
    AddRoundTimeReq("1705154400000x001", Json::Write(finPl));
}

void TestReq1a() {
    // {
//     "ubisoftUid": "0782eabd-e9ce-473b-a293-c1dd846e749b",
//     "finishTime": 68999,
//     "trackNum": 1,
//     "roundNum": 1,
//     "mapId": "testId"
// }
    auto finPl = MakePlayerFinishPayload("0782eabd-e9ce-473b-a293-c1dd846e749b", 68999, 1, 1, "testId+"+Time::Now);
    AddRoundTimeReq("1705154400000x001", Json::Write(finPl));
}

void TestReq2() {
    auto finPl = MakeRoundEndPayload({PlayerFinishData("6c51c127-a155-4d8b-8172-4508e5aec8e4", 1234, 1), PlayerFinishData("0782eabd-e9ce-473b-a293-c1dd846e749b", 12345, 2)}, 4, 5, "4TN4MeQNwtr161g31CybCw9NKAa"+Time::Now);
    AddRoundTimeReq("1705154400000x001", Json::Write(finPl));
}
