import XCTest
@testable import LotteryKit

final class DataSourceParsingTests: XCTestCase {
    func testSportteryParse() throws {
        let json = """
        {"value":{"list":[{"lotteryDrawNum":"24001","lotteryDrawResult":"05 12 18 25 33 04 11","lotteryDrawTime":"2024-01-01","prizeLevelList":[{"prizeLevel":"一等奖","stakeAmount":"10000000"},{"prizeLevel":"二等奖","stakeAmount":"200000"}]}]}}
        """.data(using: .utf8)!
        let r = try SportteryDataSource.parse(json, issue: "24001")
        XCTAssertEqual(r.frontNumbers, [5,12,18,25,33])
        XCTAssertEqual(r.backNumbers, [4,11])
        XCTAssertEqual(r.prizes?["一等奖"], 10000000)
        XCTAssertEqual(r.source, .officialSporttery)
    }

    func testCWLParse() throws {
        let json = """
        {"result":[{"code":"24001","red":"01,02,03,04,05,06","blue":"16","date":"2024-01-01(日)","prizegrades":[{"type":1,"typemoney":"8000000"},{"type":2,"typemoney":"200000"}]}]}
        """.data(using: .utf8)!
        let r = try CWLDataSource.parse(json, issue: "24001")
        XCTAssertEqual(r.frontNumbers, [1,2,3,4,5,6])
        XCTAssertEqual(r.backNumbers, [16])
        XCTAssertEqual(r.prizes?["一等奖"], 8000000)
        XCTAssertEqual(r.source, .officialCWL)
    }

    func testWebServiceParse() throws {
        let json = """
        {"category":"ssq","issue":"24001","frontNumbers":[1,2,3,4,5,6],"backNumbers":[16],"drawDate":"2024-01-01","prizes":{"一等奖":5000000}}
        """.data(using: .utf8)!
        let r = try WebServiceDataSource.parse(json, baseURL: "http://h:8080")
        XCTAssertEqual(r.backNumbers, [16])
        XCTAssertEqual(r.prizes?["一等奖"], 5000000)
        XCTAssertEqual(r.source, .webService)
        XCTAssertEqual(r.sourceURL, "http://h:8080/api/v1/draws/ssq/24001")
    }

    func testSportteryNotFound() {
        let json = "{\"value\":{\"list\":[]}}".data(using: .utf8)!
        XCTAssertThrowsError(try SportteryDataSource.parse(json, issue: "x"))
    }
}
