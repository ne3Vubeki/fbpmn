import { HttpClient } from "@angular/common/http";
import { Injectable } from "@angular/core";
import { QUrlService } from "@diasoft/qpalette-urls";

export class ApiUrl extends QUrlService {}

@Injectable()
export class ApiService {
	constructor(
		private http: HttpClient,
		private readonly gateway: ApiUrl
	) {}

  // Загрузка списка проектов по фильтрам
	getProjects(filter: any = []): Promise<any> {
		return this.http.get<any>(this.gateway.url(`/HealthProjects?${filter.join("&")}`)).toPromise();
	}

  // Загрузка объекта проекта по ID
	getProject(healthProjectId: string): Promise<any> {
		return this.http.get<any>(this.gateway.url(`/HealthProject/${healthProjectId}`)).toPromise();
	}
}
