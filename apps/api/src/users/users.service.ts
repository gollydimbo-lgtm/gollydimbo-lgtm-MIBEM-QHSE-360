import { Injectable, BadRequestException } from '@nestjs/common'; import { PrismaService } from '../common/prisma.service'; import * as bcrypt from 'bcrypt';
@Injectable() export class UsersService{constructor(private db:PrismaService){} list(){return this.db.user.findMany({select:{id:true,email:true,firstName:true,lastName:true,status:true,roles:{include:{role:true}}},orderBy:{lastName:'asc'}})}
 async create(b:{email:string;password:string;firstName:string;lastName:string;role:string}){
  if(!b?.email||!b?.password||!b?.firstName||!b?.lastName||!b?.role) throw new BadRequestException('email, password, firstName, lastName et role sont obligatoires');
  if(b.password.length<8) throw new BadRequestException('Le mot de passe doit contenir au moins 8 caractères');
  const passwordHash=await bcrypt.hash(b.password,10);
  const role=await this.db.role.upsert({where:{name:b.role as any},update:{},create:{name:b.role as any}});
  const user=await this.db.user.create({data:{email:b.email.toLowerCase(),passwordHash,firstName:b.firstName,lastName:b.lastName,roles:{create:[{roleId:role.id}]}}});
  return this.db.user.findUnique({where:{id:user.id},select:{id:true,email:true,firstName:true,lastName:true,status:true,roles:{include:{role:true}}}});
 }
 updateStatus(id:string,status:'ACTIVE'|'INACTIVE'){return this.db.user.update({where:{id},data:{status:status as any},select:{id:true,email:true,status:true}})}
 async resetPassword(id:string,newPassword:string){
  if(!newPassword||newPassword.length<8) throw new BadRequestException('Le mot de passe doit contenir au moins 8 caractères');
  const passwordHash=await bcrypt.hash(newPassword,10);
  await this.db.user.update({where:{id},data:{passwordHash}});
  return {success:true};
 }
}
