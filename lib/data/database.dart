import 'package:hive/hive.dart';

class ToDoDataBase {
  List doToList = [];

  // refernce our box
  final _myBox = Hive.box('mybox');

  //run this method if this is the 1st time ever opening this app
  void createInitialData() {
    doToList = [
      ["Make Turorial", false],
      ["Do Exercise", false],
    ];
  }

  //load the data from database
  void laodData() {
    doToList = _myBox.get("TODOLIST");
  }

  //update database
  void updateDataBase() {
    _myBox.put("TODOLIST", doToList);
  }
}
