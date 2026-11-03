class_name GameTestCase
extends Node
## Base class for tests run by res://tests/run_tests.gd.
## Every method whose name starts with "test_" is a test. Tests may use `await`.

var _failures: PackedStringArray = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func take_failures() -> PackedStringArray:
	var result := _failures
	_failures = []
	return result


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String) -> void:
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		fail("%s (expected %.3f +/- %.3f, got %.3f)" % [message, expected, tolerance, actual])


func assert_gt(actual: float, threshold: float, message: String) -> void:
	if not actual > threshold:
		fail("%s (expected > %.3f, got %.3f)" % [message, threshold, actual])


func assert_lt(actual: float, threshold: float, message: String) -> void:
	if not actual < threshold:
		fail("%s (expected < %.3f, got %.3f)" % [message, threshold, actual])


## Waits for `count` physics ticks.
func physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
