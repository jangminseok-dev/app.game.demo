import 'package:idle_fantasy/data/save_repository.dart';
import 'package:idle_fantasy/domain/save_codec.dart';

/// 테스트용 저장소. 저장 호출 횟수와 마지막 데이터를 기억한다.
class InMemorySaveRepository implements SaveRepository {
  InMemorySaveRepository([this.stored]);

  SaveData? stored;
  int saveCount = 0;

  @override
  Future<SaveData?> load() async => stored;

  @override
  Future<void> save(SaveData data) async {
    stored = data;
    saveCount++;
  }
}
