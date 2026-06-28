public enum NumberValidation {
    public static func validate(category: Category, front: [Int], back: [Int]) -> String? {
        if let e = check("前区/红球", front, category.frontCount, category.frontMax) { return e }
        if let e = check("后区/蓝球", back, category.backCount, category.backMax) { return e }
        return nil
    }

    public static func validateBet(category: Category, front: [Int], back: [Int]) -> String? {
        if let e = checkAtLeast("前区/红球", front, category.frontCount, category.frontMax) { return e }
        if let e = checkAtLeast("后区/蓝球", back, category.backCount, category.backMax) { return e }
        return nil
    }

    private static func check(_ name: String, _ nums: [Int], _ count: Int, _ maxV: Int) -> String? {
        if nums.count != count { return "\(name)必须为 \(count) 个号码" }
        return checkCommon(name, nums, maxV)
    }

    private static func checkAtLeast(_ name: String, _ nums: [Int], _ count: Int, _ maxV: Int) -> String? {
        if nums.count < count { return "\(name)至少需要 \(count) 个号码" }
        return checkCommon(name, nums, maxV)
    }

    private static func checkCommon(_ name: String, _ nums: [Int], _ maxV: Int) -> String? {
        if Set(nums).count != nums.count { return "\(name)不能重复" }
        for n in nums where n < 1 || n > maxV { return "\(name)范围应为 1-\(maxV)" }
        return nil
    }
}
