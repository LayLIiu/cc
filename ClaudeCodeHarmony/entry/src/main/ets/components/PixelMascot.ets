/**
 * 像素风格吉祥物
 * 完全还原 iOS 端 PixelMascot
 */

// 吉祥物状态
export enum MascotStatus {
  Idle = 'idle',
  Processing = 'processing',
  WaitingApproval = 'waitingApproval',
  Completed = 'completed'
}

@Component
export struct PixelMascot {
  @Prop pixelSize: number = 27;
  @Prop status: MascotStatus = MascotStatus.Idle;
  @Prop bodyColor: string = '#E86B4A';

  private eyeColor: string = '#1A1A1A';
  private alertColor: string = '#FF3D00';
  private kbBaseColor: string = '#616E7A';
  private kbKeyColor: string = '#9AA8B4';
  private successColor: string = '#22C55E';
  private starColor: string = '#FBBF24';

  // 动画时间
  @State private animTime: number = 0;
  private animTimer: number = -1;

  aboutToAppear() {
    this.startAnimation();
  }

  aboutToDisappear() {
    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
    }
  }

  private startAnimation() {
    this.animTimer = setInterval(() => {
      this.animTime += 0.05;
    }, 50);
  }

  build() {
    Stack() {
      if (this.status === MascotStatus.Idle) {
        this.SleepingMascot()
      } else if (this.status === MascotStatus.Processing) {
        this.WorkingMascot()
      } else if (this.status === MascotStatus.WaitingApproval) {
        this.AlertMascot()
      } else {
        this.CompletedMascot()
      }
    }
    .width(this.pixelSize)
    .height(this.pixelSize)
  }

  // 睡眠状态
  @Builder
  SleepingMascot() {
    Stack() {
      // 身体
      Column() {}
        .width(this.pixelSize * 0.75)
        .height(this.pixelSize * 0.45)
        .backgroundColor(this.bodyColor)
        .borderRadius(2)

      // 眼睛（闭着的）
      Row() {
        Column() {}
          .width(this.pixelSize * 0.15)
          .height(this.pixelSize * 0.06)
          .backgroundColor(this.eyeColor)
          .borderRadius(1)

        Column() {}
          .width(this.pixelSize * 0.15)
          .height(this.pixelSize * 0.06)
          .backgroundColor(this.eyeColor)
          .borderRadius(1)
          .margin({ left: this.pixelSize * 0.25 })
      }
      .margin({ top: this.pixelSize * 0.1 })

      // 腿
      Row() {
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.15)
          .backgroundColor(this.bodyColor)
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.15)
          .backgroundColor(this.bodyColor)
          .margin({ left: this.pixelSize * 0.1 })
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.15)
          .backgroundColor(this.bodyColor)
          .margin({ left: this.pixelSize * 0.15 })
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.15)
          .backgroundColor(this.bodyColor)
          .margin({ left: this.pixelSize * 0.1 })
      }
      .margin({ top: this.pixelSize * 0.55 })

      // ZZZ 睡眠符号
      Text('z')
        .fontSize(this.pixelSize * 0.22)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .position({ x: this.pixelSize * 0.75, y: -this.pixelSize * 0.1 })

      Text('z')
        .fontSize(this.pixelSize * 0.18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .position({ x: this.pixelSize * 0.85, y: -this.pixelSize * 0.2 })

      Text('z')
        .fontSize(this.pixelSize * 0.14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .position({ x: this.pixelSize * 0.95, y: -this.pixelSize * 0.3 })
    }
    .width(this.pixelSize)
    .height(this.pixelSize)
  }

  // 工作状态
  @Builder
  WorkingMascot() {
    Stack() {
      // 身体
      Column() {}
        .width(this.pixelSize * 0.7)
        .height(this.pixelSize * 0.45)
        .backgroundColor(this.bodyColor)
        .borderRadius(2)

      // 眼睛（睁开的）
      Row() {
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.08)
          .backgroundColor(this.eyeColor)

        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.08)
          .backgroundColor(this.eyeColor)
          .margin({ left: this.pixelSize * 0.25 })
      }
      .margin({ top: this.pixelSize * 0.15 })

      // 手臂
      Row() {
        Column() {}
          .width(this.pixelSize * 0.12)
          .height(this.pixelSize * 0.15)
          .backgroundColor(this.bodyColor)

        Blank()

        Column() {}
          .width(this.pixelSize * 0.12)
          .height(this.pixelSize * 0.15)
          .backgroundColor(this.bodyColor)
      }
      .width(this.pixelSize * 1.1)
      .margin({ top: this.pixelSize * 0.3 })

      // 腿
      Row() {
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.12)
          .backgroundColor(this.bodyColor)
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.12)
          .backgroundColor(this.bodyColor)
          .margin({ left: this.pixelSize * 0.1 })
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.12)
          .backgroundColor(this.bodyColor)
          .margin({ left: this.pixelSize * 0.15 })
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.12)
          .backgroundColor(this.bodyColor)
          .margin({ left: this.pixelSize * 0.1 })
      }
      .margin({ top: this.pixelSize * 0.55 })

      // 键盘底座
      Column() {}
        .width(this.pixelSize)
        .height(this.pixelSize * 0.22)
        .backgroundColor(this.kbBaseColor)
        .borderRadius(2)
        .margin({ top: this.pixelSize * 0.75 })

      // 键盘按键
      Row() {
        ForEach([0, 1, 2, 3, 4], () => {
          Column() {}
            .width(this.pixelSize * 0.1)
            .height(this.pixelSize * 0.05)
            .backgroundColor(this.kbKeyColor)
            .borderRadius(1)
            .margin({ right: 2 })
        })
      }
      .margin({ top: this.pixelSize * 0.78 })

      Row() {
        ForEach([0, 1, 2, 3, 4], () => {
          Column() {}
            .width(this.pixelSize * 0.1)
            .height(this.pixelSize * 0.05)
            .backgroundColor(this.kbKeyColor)
            .borderRadius(1)
            .margin({ right: 2 })
        })
      }
      .margin({ top: this.pixelSize * 0.85 })
    }
    .width(this.pixelSize)
    .height(this.pixelSize)
  }

  // 警告状态
  @Builder
  AlertMascot() {
    Stack() {
      // 身体
      Column() {}
        .width(this.pixelSize * 0.7)
        .height(this.pixelSize * 0.45)
        .backgroundColor(this.bodyColor)
        .borderRadius(2)

      // 大眼睛
      Row() {
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.18)
          .backgroundColor(this.eyeColor)

        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.18)
          .backgroundColor(this.eyeColor)
          .margin({ left: this.pixelSize * 0.25 })
      }
      .margin({ top: this.pixelSize * 0.12 })

      // 举起的手臂
      Row() {
        Column() {}
          .width(this.pixelSize * 0.12)
          .height(this.pixelSize * 0.35)
          .backgroundColor(this.bodyColor)

        Blank()

        Column() {}
          .width(this.pixelSize * 0.12)
          .height(this.pixelSize * 0.35)
          .backgroundColor(this.bodyColor)
      }
      .width(this.pixelSize * 1.1)
      .margin({ top: this.pixelSize * 0.1 })

      // 腿
      Row() {
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.25)
          .backgroundColor(this.bodyColor)
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.25)
          .backgroundColor(this.bodyColor)
          .margin({ left: this.pixelSize * 0.1 })
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.25)
          .backgroundColor(this.bodyColor)
          .margin({ left: this.pixelSize * 0.15 })
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.25)
          .backgroundColor(this.bodyColor)
          .margin({ left: this.pixelSize * 0.1 })
      }
      .margin({ top: this.pixelSize * 0.55 })

      // 警告符号
      Text('!')
        .fontSize(this.pixelSize * 0.35)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.alertColor)
        .position({ x: this.pixelSize * 0.9, y: this.pixelSize * 0.1 })
    }
    .width(this.pixelSize)
    .height(this.pixelSize)
  }

  // 完成状态
  @Builder
  CompletedMascot() {
    Stack() {
      // 身体
      Column() {}
        .width(this.pixelSize * 0.7)
        .height(this.pixelSize * 0.4)
        .backgroundColor(this.bodyColor)
        .borderRadius(2)

      // 开心的眼睛
      Row() {
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.08)
          .backgroundColor(this.eyeColor)

        Column() {}
          .width(this.pixelSize * 0.05)
          .height(this.pixelSize * 0.05)
          .backgroundColor(this.eyeColor)
          .margin({ left: 0, top: this.pixelSize * 0.05 })

        Blank()

        Column() {}
          .width(this.pixelSize * 0.05)
          .height(this.pixelSize * 0.05)
          .backgroundColor(this.eyeColor)
          .margin({ right: 0, top: this.pixelSize * 0.05 })

        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.08)
          .backgroundColor(this.eyeColor)
      }
      .width(this.pixelSize * 0.5)
      .margin({ top: this.pixelSize * 0.15 })

      // 微笑
      Column() {}
        .width(this.pixelSize * 0.2)
        .height(this.pixelSize * 0.05)
        .backgroundColor(this.eyeColor)
        .borderRadius(this.pixelSize * 0.03)
        .margin({ top: this.pixelSize * 0.35 })

      // 举起的手臂 - 庆祝
      Column() {}
        .width(this.pixelSize * 0.12)
        .height(this.pixelSize * 0.35)
        .backgroundColor(this.bodyColor)
        .position({ x: -this.pixelSize * 0.1, y: this.pixelSize * 0.1 })

      Column() {}
        .width(this.pixelSize * 0.12)
        .height(this.pixelSize * 0.35)
        .backgroundColor(this.bodyColor)
        .position({ x: this.pixelSize * 0.95, y: this.pixelSize * 0.1 })

      // 腿
      Row() {
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.18)
          .backgroundColor(this.bodyColor)
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.18)
          .backgroundColor(this.bodyColor)
          .margin({ left: this.pixelSize * 0.1 })
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.18)
          .backgroundColor(this.bodyColor)
          .margin({ left: this.pixelSize * 0.15 })
        Column() {}
          .width(this.pixelSize * 0.08)
          .height(this.pixelSize * 0.18)
          .backgroundColor(this.bodyColor)
          .margin({ left: this.pixelSize * 0.1 })
      }
      .margin({ top: this.pixelSize * 0.55 })

      // 星星
      Text('★')
        .fontSize(this.pixelSize * 0.15)
        .fontColor(this.starColor)
        .position({ x: -this.pixelSize * 0.15, y: 0 })

      Text('★')
        .fontSize(this.pixelSize * 0.12)
        .fontColor(this.starColor)
        .position({ x: this.pixelSize, y: -this.pixelSize * 0.05 })
    }
    .width(this.pixelSize)
    .height(this.pixelSize)
  }
}

// 会话状态映射到吉祥物状态
export function mapSessionStatusToMascot(status: string): MascotStatus {
  switch (status) {
    case 'thinking':
    case 'streaming':
    case 'tool_executing':
      return MascotStatus.Processing;
    case 'permission_pending':
    case 'question_pending':
      return MascotStatus.WaitingApproval;
    case 'completed':
      return MascotStatus.Completed;
    default:
      return MascotStatus.Idle;
  }
}
