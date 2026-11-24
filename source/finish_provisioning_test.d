import std.exception : assertThrown, collectException;
import std.string : indexOf;

import provision.adi;

// "AQIDBA==" is 01 02 03 04, "BQYHCA==" is 05 06 07 08.
enum ptm = "AQIDBA==";
enum tk = "BQYHCA==";

string finishPlist(string responseInner) {
    return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Response</key>
	<dict>
` ~ responseInner ~ `
	</dict>
</dict>
</plist>`;
}

enum string rinfoKey = `
		<key>X-Apple-I-MD-RINFO</key>
		<string>17106176</string>`;

enum string tokens = `
		<key>ptm</key>
		<string>` ~ ptm ~ `</string>
		<key>tk</key>
		<string>` ~ tk ~ `</string>`;

void assertDecodedTokens(FinishProvisioningResponse fields) {
    assert(fields.persistentTokenMetadata == [1, 2, 3, 4]);
    assert(fields.trustKey == [5, 6, 7, 8]);
}

void assertMissing(string xml, string key) {
    auto ex = collectException!ProvisioningException(parseFinishProvisioningResponse(xml));
    assert(ex !is null, "expected a provisioning error");
    assert(ex.msg.indexOf(key) >= 0, ex.msg);
    assert(ex.msg.indexOf("required") >= 0, ex.msg);
}

unittest {
    auto fields = parseFinishProvisioningResponse(finishPlist(rinfoKey ~ tokens));
    assert(fields.hasRoutingInformation);
    assert(fields.routingInformation == 17106176);
    assertDecodedTokens(fields);
}

unittest {
    auto fields = parseFinishProvisioningResponse(finishPlist(tokens ~ `
		<key>Status</key>
		<dict>
			<key>ec</key>
			<integer>0</integer>
			<key>em</key>
			<string>ok</string>
		</dict>`));
    assert(!fields.hasRoutingInformation);
    assert(fields.routingInformation == 0);
    assertDecodedTokens(fields);
}

unittest {
    assertMissing(finishPlist(`
		<key>tk</key>
		<string>` ~ tk ~ `</string>`), "ptm");
    assertMissing(finishPlist(`
		<key>ptm</key>
		<string>` ~ ptm ~ `</string>`), "tk");
    assertMissing(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Header</key>
	<dict/>
</dict>
</plist>`, "Response");
}

unittest {
    auto refused = collectException!ProvisioningException(parseFinishProvisioningResponse(finishPlist(`
		<key>Status</key>
		<dict>
			<key>ec</key>
			<integer>-80045</integer>
			<key>em</key>
			<string>This action cannot be completed at this time.</string>
			<key>ed</key>
			<string></string>
		</dict>
		<key>ptxid</key>
		<string>abc</string>`)));
    assert(refused !is null);
    assert(refused.msg.indexOf("Apple finish provisioning failed") >= 0, refused.msg);
    assert(refused.msg.indexOf("ec=-80045") >= 0, refused.msg);
    assert(refused.msg.indexOf("cannot be completed") >= 0, refused.msg);
}

unittest {
    auto badRinfo = collectException!ProvisioningException(parseFinishProvisioningResponse(finishPlist(`
		<key>X-Apple-I-MD-RINFO</key>
		<string>not-a-number</string>` ~ tokens)));
    assert(badRinfo !is null);
    assert(badRinfo.msg.indexOf("X-Apple-I-MD-RINFO") >= 0, badRinfo.msg);

    auto badPtm = collectException!ProvisioningException(parseFinishProvisioningResponse(finishPlist(`
		<key>ptm</key>
		<string>!!!!</string>
		<key>tk</key>
		<string>` ~ tk ~ `</string>`)));
    assert(badPtm !is null);
    assert(badPtm.msg.indexOf("ptm") >= 0, badPtm.msg);
    assert(badPtm.next !is null);

    assertThrown!ProvisioningException(parseFinishProvisioningResponse(""));
    assertThrown!ProvisioningException(parseFinishProvisioningResponse(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array/>
</plist>`));
}
