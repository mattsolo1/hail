package is.hail.kryo

import org.apache.spark.serializer.KryoRegistrator
import com.esotericsoftware.kryo.Kryo
import com.esotericsoftware.kryo.serializers.JavaSerializer
import is.hail.annotations.{Region, UnsafeIndexedSeq, UnsafeRow}
import is.hail.utils.{Interval, SerializableHadoopConfiguration}
import is.hail.variant.Locus
import org.apache.spark.sql.catalyst.expressions.GenericRow

class HailKryoRegistrator extends KryoRegistrator {
  override def registerClasses(kryo: Kryo) {
    kryo.register(classOf[SerializableHadoopConfiguration], new JavaSerializer())
    kryo.register(classOf[UnsafeRow])
    kryo.register(classOf[GenericRow])
    kryo.register(classOf[Locus])
    kryo.register(classOf[Interval])
    kryo.register(classOf[UnsafeIndexedSeq])
    kryo.register(classOf[Region])
  }
}
