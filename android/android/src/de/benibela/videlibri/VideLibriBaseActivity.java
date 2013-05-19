package de.benibela.videlibri;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import de.benibela.videlibri.imported.*;
import android.app.Activity;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.widget.TextView;

public class VideLibriBaseActivity extends Activity {
    final ActionBarHelper mActionBarHelper = ActionBarHelper.createInstance(this);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);    //To change body of overridden methods use File | Settings | File Templates.
        mActionBarHelper.onCreate(savedInstanceState);
    }

    @Override
    protected void onPostCreate(Bundle savedInstanceState) {
        super.onPostCreate(savedInstanceState);    //To change body of overridden methods use File | Settings | File Templates.
        mActionBarHelper.onPostCreate(savedInstanceState);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = mActionBarHelper.getMenuInflater(super.getMenuInflater());
        inflater.inflate(R.menu.videlibrimenu, menu);
        return super.onCreateOptionsMenu(menu);
    }

    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle item selection
        switch (item.getItemId()) {
            case R.id.search:
                VideLibri.newSearchActivity();
                return true;
            default:
                return super.onOptionsItemSelected(item);
        }
    }


    //Util
    String getStringExtraSafe(String id){
        String r = getIntent().getStringExtra(id);
        if (r == null) return "";
        return  r;
    }

    public void setTextViewText(int id, CharSequence text){
        TextView tv = (TextView) findViewById(id);
        tv.setText(text);
    }

    public String getTextViewText(int id){
        TextView tv = (TextView) findViewById(id);
        return tv.getText().toString();
    }

    static interface MessageHandler{
        void onDialogEnd(DialogInterface dialogInterface, int i);
    }
    static int MessageHandlerCanceled = -1;


    public void showMessage(String message){ showMessage(this, message, null); }
    public void showMessage(String message, MessageHandler handler){ showMessage(this, message, null); }
    static public void showMessage(Context context, String message, final MessageHandler handler){
        AlertDialog.Builder builder = new AlertDialog.Builder(context);
        builder.setMessage(message);
        builder.setTitle("VideLibri");
        builder.setNegativeButton("OK", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                if (handler != null) handler.onDialogEnd(dialogInterface, i);
            }
        });
        if (handler != null) {
            builder.setOnCancelListener(new DialogInterface.OnCancelListener() {
                @Override
                public void onCancel(DialogInterface dialogInterface) {
                    handler.onDialogEnd(dialogInterface, MessageHandlerCanceled);
                }
            });
        }
        builder.show();
    }
}
