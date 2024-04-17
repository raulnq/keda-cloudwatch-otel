import http from 'k6/http';
import { sleep } from 'k6';
export const options = {
    vus: 50,
    duration: '600s',
};
export default function () {
    http.get('<URL>/weatherforecast');
    sleep(1);
}
