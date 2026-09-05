import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto';

@Controller('auth')
export class AuthController {
  constructor(private s: AuthService) {}
  @Post('login') login(@Body() d: LoginDto) { return this.s.login(d); }
  @Post('refresh') refresh(@Body() b: { refreshToken: string }) { return this.s.refresh(b.refreshToken); }
  @Post('logout') logout(@Body() b: { refreshToken: string }) { return this.s.logout(b.refreshToken); }
  @Post('change-password') changePassword(@Body() b: { email: string; currentPassword: string; newPassword: string }) {
    return this.s.changePassword(b.email, b.currentPassword, b.newPassword);
  }
}
