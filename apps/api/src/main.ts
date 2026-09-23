import { NestFactory } from '@nestjs/core'; import { ValidationPipe } from '@nestjs/common'; import { AppModule } from './app.module'; import { join } from 'path'; import * as express from 'express'; import { createAuditContextMiddleware } from './common/audit-context.middleware';
import { ConfigService } from '@nestjs/config';
import { StripForbiddenFieldsInterceptor } from './common/strip-forbidden-fields.interceptor';
// Liste blanche CORS (audit finding #3) — origin:true reflétait
// n'importe quelle origine avec les identifiants (credentials:true),
// un vecteur CSRF/vol de session depuis un site tiers. CORS_ORIGINS
// (variable d'env, séparée par des virgules) doit lister l'adresse
// réelle du web (ex. http://192.168.1.50:5173) en production. Sans
// cette variable, on retombe sur un jeu d'origines locales par défaut
// (localhost/127.0.0.1) plutôt que de tout accepter — donc le premier
// déploiement sans configurer CORS_ORIGINS n'est plus ouvert par
// défaut, mais devra explicitement lister son adresse LAN.
const DEFAULT_CORS_ORIGINS = ['http://localhost:5173', 'http://127.0.0.1:5173'];
const corsOrigins = (process.env.CORS_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean);
const allowedOrigins = corsOrigins.length ? corsOrigins : DEFAULT_CORS_ORIGINS;

async function bootstrap(){const app=await NestFactory.create(AppModule);app.setGlobalPrefix('api/v4');app.useGlobalPipes(new ValidationPipe({transform:true,whitelist:true}));app.useGlobalInterceptors(new StripForbiddenFieldsInterceptor());app.enableCors({origin:(origin:string|undefined,callback:(err:Error|null,allow?:boolean)=>void)=>{if(!origin||allowedOrigins.includes(origin))return callback(null,true);return callback(new Error(`Origine CORS non autorisée : ${origin}. Ajoutez-la à la variable d'environnement CORS_ORIGINS.`));},credentials:true});app.use(createAuditContextMiddleware(app.get(ConfigService).get('JWT_SECRET') || ''));app.use('/uploads',express.static(join(process.cwd(),'uploads')));await app.listen(process.env.PORT||3000,'0.0.0.0');}bootstrap();
