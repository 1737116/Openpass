
enum FieldType {
  text,         // '-'
  url,          // ':'
  email,        // '@'
  address,      // '#'
  date,         // '/'
  otp,          // '^'
  password,     // '*'
  phone,        // '+'
  multilineText,// '~'
  loginMethod,  // '%'
  file,         // '&'
  photo,        // '!'
}

extension FieldTypeExtension on FieldType {
  String get displayName {
    switch (this) {
      case FieldType.text:
        return '文本';
      case FieldType.url:
        return 'URL';
      case FieldType.email:
        return '电子邮件';
      case FieldType.address:
        return '地址';
      case FieldType.date:
        return '日期';
      case FieldType.otp:
        return '一次性密码';
      case FieldType.password:
        return '密码';
      case FieldType.phone:
        return '电话';
      case FieldType.multilineText:
        return '备注';
      case FieldType.loginMethod:
        return '登录方式';
      case FieldType.file:
        return '文件';
      case FieldType.photo:
        return '照片';
    }
  }
}

class FieldTypeHelper {
  static FieldType fromString(String str) {
    switch (str) {
      case '-':
        return FieldType.text;
      case ':':
        return FieldType.url;
      case '@':
        return FieldType.email;
      case '#':
        return FieldType.address;
      case '/':
        return FieldType.date;
      case '^':
        return FieldType.otp;
      case '*':
        return FieldType.password;
      case '+':
        return FieldType.phone;
      case '~':
        return FieldType.multilineText;
      case '%':
        return FieldType.loginMethod;
      case '&':
        return FieldType.file;
      case '!':
        return FieldType.photo;
      default:
        return FieldType.text;
    }
  }
  static String fromType(FieldType t){
    switch (t) {
      case FieldType.text:
        return '-';
      case FieldType.url:
        return ':';
      case FieldType.email:
        return '@';
      case FieldType.address:
        return '#';
      case FieldType.date:
        return '/';
      case FieldType.otp:
        return '^';
      case FieldType.password:
        return '*';
      case FieldType.phone:
        return '+';
      case FieldType.multilineText:
        return '~';
      case FieldType.loginMethod:
        return '%';
      case FieldType.file:
        return '&';
      case FieldType.photo:
        return '!';
    }
  }
}