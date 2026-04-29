/**
 * 登录页面
 * 完全还原 iOS 端 UI
 */

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'LoginPage';

@Entry
@Component
struct Index {
  @State private mode: string = 'pairing'; // pairing | manual
  @State private pairingCode: string = '';
  @State private serverUrl: string = '';
  @State private isConnecting: boolean = false;
  @State private errorMessage: string = '';

  build() {
    Column() {
      Scroll() {
        Column() {
          // Logo 区域
          Column() {
            Text('💬')
              .fontSize(64)
              .margin({ bottom: 16 })

            Text('Claude Code')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')

            Text('移动端助手')
              .fontSize(16)
              .fontColor('#6B6B6B')
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 60, bottom: 32 })

          // 模式切换 - 胶囊样式
          Row() {
            // 配对码连接
            Column() {
              Text('配对码连接')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.mode === 'pairing' ? '#6366F1' : '#6B6B6B')
            }
            .width('50%')
            .height(44)
            .justifyContent(FlexAlign.Center)
            .borderRadius(8)
            .backgroundColor(this.mode === 'pairing' ? '#6366F115' : 'transparent')
            .onClick(() => {
              this.mode = 'pairing';
              this.errorMessage = '';
            })

            // 手动输入
            Column() {
              Text('手动输入')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.mode === 'manual' ? '#6366F1' : '#6B6B6B')
            }
            .width('50%')
            .height(44)
            .justifyContent(FlexAlign.Center)
            .borderRadius(8)
            .backgroundColor(this.mode === 'manual' ? '#6366F115' : 'transparent')
            .onClick(() => {
              this.mode = 'manual';
              this.errorMessage = '';
            })
          }
          .width('100%')
          .padding({ left: 32, right: 32 })
          .margin({ bottom: 24 })

          // 输入区域
          if (this.mode === 'pairing') {
            this.PairingInputView()
          } else {
            this.ManualInputView()
          }

          // 使用步骤说明
          this.InstructionsView()
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
  }

  // 配对码输入
  @Builder
  PairingInputView() {
    Column() {
      // 输入框
      Column() {
        Text('配对码')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
          .width('100%')
          .margin({ bottom: 8 })

        TextInput({ placeholder: '粘贴连接串或 IP:端口:配对码', text: this.pairingCode })
          .width('100%')
          .height(44)
          .fontSize(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.pairingCode = value;
            this.errorMessage = '';
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 32, right: 32 })
      .margin({ bottom: 12 })

      // 提示文字
      Text('支持局域网或公网隧道连接，在桌面端获取配对码')
        .fontSize(13)
        .fontColor('#6B6B6B')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ left: 32, right: 32 })
        .margin({ bottom: 12 })

      // 错误提示
      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(13)
          .fontColor('#FF3B30')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })
          .margin({ bottom: 12 })
      }

      // 连接按钮
      Button() {
        if (this.isConnecting) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(Color.White)
        } else {
          Text('配对连接')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
      }
      .width('100%')
      .height(50)
      .backgroundColor(this.pairingCode.length > 0 ? '#6366F1' : '#C7C7CC')
      .borderRadius(12)
      .margin({ left: 32, right: 32 })
      .enabled(this.pairingCode.length > 0 && !this.isConnecting)
      .onClick(() => {
        this.handleConnect();
      })
    }
    .width('100%')
  }

  // 手动输入
  @Builder
  ManualInputView() {
    Column() {
      // 输入框
      Column() {
        Text('服务器地址')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
          .width('100%')
          .margin({ bottom: 8 })

        TextInput({ placeholder: 'http://192.168.1.100:3456', text: this.serverUrl })
          .width('100%')
          .height(44)
          .fontSize(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.serverUrl = value;
            this.errorMessage = '';
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 32, right: 32 })
      .margin({ bottom: 12 })

      // 提示文字
      Text('请输入桌面端服务地址（确保手机和电脑在同一网络）')
        .fontSize(13)
        .fontColor('#6B6B6B')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ left: 32, right: 32 })
        .margin({ bottom: 12 })

      // 错误提示
      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(13)
          .fontColor('#FF3B30')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })
          .margin({ bottom: 12 })
      }

      // 连接按钮
      Button() {
        if (this.isConnecting) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(Color.White)
        } else {
          Text('连接')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
      }
      .width('100%')
      .height(50)
      .backgroundColor(this.serverUrl.length > 0 ? '#6366F1' : '#C7C7CC')
      .borderRadius(12)
      .margin({ left: 32, right: 32 })
      .enabled(this.serverUrl.length > 0 && !this.isConnecting)
      .onClick(() => {
        this.handleConnect();
      })
    }
    .width('100%')
  }

  // 使用步骤说明
  @Builder
  InstructionsView() {
    Column() {
      Text('使用步骤')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .width('100%')
        .margin({ bottom: 16 })

      this.InstructionStep(1, '在电脑上启动 Claude Code 桌面应用')
      this.InstructionStep(2, '设置 → IM 接入 → 生成配对码')
      this.InstructionStep(3, '局域网：输入 IP:端口:配对码')
      this.InstructionStep(4, '公网：粘贴完整连接串')
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#E5E5EA')
    .borderRadius(12)
    .margin({ left: 32, right: 32, top: 24 })
  }

  @Builder
  InstructionStep(number: number, text: string) {
    Row() {
      Text(number.toString())
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(24)
        .height(24)
        .textAlign(TextAlign.Center)
        .borderRadius(12)
        .backgroundColor('#6366F1')

      Text(text)
        .fontSize(13)
        .fontColor('#6B6B6B')
        .margin({ left: 12 })
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ bottom: 12 })
  }

  // 连接处理
  private handleConnect(): void {
    this.isConnecting = true;

    setTimeout(() => {
      this.isConnecting = false;
      router.replaceUrl({ url: 'pages/MainPage' });
    }, 1000);
  }
}
