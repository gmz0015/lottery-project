RULES = {
    "ssq": {"front_count": 6, "front_max": 33, "back_count": 1, "back_max": 16},
    "dlt": {"front_count": 5, "front_max": 35, "back_count": 2, "back_max": 12},
}


def _check(name: str, nums: list[int], count: int, max_v: int) -> None:
    if not isinstance(nums, list) or len(nums) != count:
        raise ValueError(f"{name}必须为 {count} 个号码")
    if len(set(nums)) != len(nums):
        raise ValueError(f"{name}不能重复")
    for n in nums:
        if not isinstance(n, int) or n < 1 or n > max_v:
            raise ValueError(f"{name}范围应为 1-{max_v}")


def validate_numbers(category: str, front: list[int], back: list[int]) -> None:
    rule = RULES.get(category)
    if rule is None:
        raise ValueError(f"未知彩种: {category}")
    _check("前区/红球", front, rule["front_count"], rule["front_max"])
    _check("后区/蓝球", back, rule["back_count"], rule["back_max"])
