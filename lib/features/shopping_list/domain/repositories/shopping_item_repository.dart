import '../entities/shopping_item.dart';

abstract interface class ShoppingItemRepository {
  /// 미완료(등록순) → 완료(등록순) 정렬된 전체 목록 스트림.
  Stream<List<ShoppingItem>> watchAll();

  /// 새 항목 추가. 이름 trim 후 공백이면 무시. 수량 기본 1.
  Future<void> add(String name);

  /// 이름 변경. trim 후 공백이면 무시.
  Future<void> rename(int id, String name);

  /// 수량 변경. 1 미만이면 1로 보정.
  Future<void> setQuantity(int id, int quantity);

  Future<void> setDone(int id, bool isDone);

  Future<void> delete(int id);
}
